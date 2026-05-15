# rmcp Reference

> Source: https://github.com/modelcontextprotocol/rust-sdk (README.md), https://docs.rs/rmcp
> Created: 2026-05-12
> Updated: 2026-05-12

## Overview

`rmcp` is the official Rust SDK for the Model Context Protocol from Anthropic. It implements the client and server side of the MCP protocol on top of the `tokio` async runtime. The current stable API version is **1.x** (raw crate version `0.16+`). It covers the MCP spec **2025-11-25**.

The workspace contains two crates:

- **`rmcp`** — the core with the protocol implementation
- **`rmcp-macros`** — procedural macros for declarative registration of tools/prompts

## Core Concepts

**Two-role architecture:**

- **`ServerHandler` trait** — implemented by the server (the MyHealth-Europe MCP server).
- **`ClientHandler` trait** — implemented by the client (Claude Desktop, Ollama, etc.).

**Transports** — a separate layer that connects a handler to concrete I/O:

- `stdio()` — standard transport for desktop LLM clients
- `(tokio::io::stdin(), tokio::io::stdout())` — manual reader+writer tuple
- `TokioChildProcess::new(Command::new(...))` — spawn a child process as an MCP server
- HTTP/SSE and other transports — via extension crates (`rmcp-actix-web`)

**Capabilities** (`ServerCapabilities::builder()`):

- `.enable_resources()` / `.enable_resources_subscribe()`
- `.enable_prompts()`
- `.enable_logging()`
- `.enable_completions()`
- The tools capability is activated automatically via the `#[tool_handler]` or `#[tool_router(server_handler)]` macro.

## API / Interface

### Installation

```toml
rmcp = { version = "0.16.0", features = ["server"] }
# or the dev channel
rmcp = { git = "https://github.com/modelcontextprotocol/rust-sdk", branch = "main" }
```

Required deps: `tokio`, `serde`. JSON-schema (2020-12): `schemars`.

### Client construction

```rust
use rmcp::{ServiceExt, transport::{TokioChildProcess, ConfigureCommandExt}};
use tokio::process::Command;

let client = ().serve(TokioChildProcess::new(Command::new("npx").configure(|cmd| {
    cmd.arg("-y").arg("@modelcontextprotocol/server-everything");
}))?).await?;
```

### Server construction (minimal)

```rust
use rmcp::{handler::server::wrapper::Parameters, schemars, tool, tool_router, ServiceExt, transport::stdio};

#[derive(Debug, serde::Deserialize, schemars::JsonSchema)]
struct AddParams { a: i32, b: i32 }

#[derive(Clone)]
struct Calculator;

#[tool_router(server_handler)]
impl Calculator {
    #[tool(description = "Add two numbers")]
    fn add(&self, Parameters(AddParams { a, b }): Parameters<AddParams>) -> String {
        (a + b).to_string()
    }
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let service = Calculator.serve(stdio()).await?;
    service.waiting().await?;
    Ok(())
}
```

### Server with custom metadata + multiple capabilities

```rust
#[tool_router]
impl Calculator { /* ... */ }

#[tool_handler(name = "calculator", version = "1.0.0", instructions = "A simple calculator")]
impl ServerHandler for Calculator {}
```

### Lifecycle

```rust
// Server side
let server = service.serve(transport).await?;          // handshake + initialization
let quit_reason = server.waiting().await?;             // blocks until shutdown
// or
let quit_reason = server.cancel().await?;              // explicit cancellation

// Client side requests
let roots = server.list_roots().await?;
server.notify_cancelled(...).await?;
```

## MCP Primitives — how to do each one

### Tools

Server-side: `#[tool]` on a method + `#[tool_router]` on the impl. Tool parameters — a struct with `schemars::JsonSchema`.

Client-side:

```rust
use rmcp::model::CallToolRequestParams;
let tools = client.list_all_tools().await?;
let result = client.call_tool(CallToolRequestParams::new("add")).await?;
```

### Resources

Server-side: implement `list_resources()`, `read_resource()`, optionally `list_resource_templates()` on `ServerHandler`. Capability: `.enable_resources()`.

```rust
async fn read_resource(
    &self,
    request: ReadResourceRequestParams,
    _context: RequestContext<RoleServer>,
) -> Result<ReadResourceResult, McpError> {
    match request.uri.as_str() {
        "file:///config.json" => Ok(ReadResourceResult {
            contents: vec![ResourceContents::text(r#"{"key": "value"}"#, &request.uri)],
        }),
        _ => Err(McpError::resource_not_found("resource_not_found", Some(json!({ "uri": request.uri })))),
    }
}
```

Notify on change: `context.peer.notify_resource_list_changed().await?`, `context.peer.notify_resource_updated(...)`.

Client-side: `client.list_all_resources().await?`, `client.read_resource(ReadResourceRequestParams { uri: "...".into(), .. }).await?`.

### Prompts

Server-side: `#[prompt_router]` + `#[prompt]` + `#[prompt_handler]`. Prompt parameters — a struct with `JsonSchema`.

```rust
#[prompt(name = "code_review", description = "Review code in a given language")]
async fn code_review(&self, Parameters(args): Parameters<CodeReviewArgs>) -> Result<GetPromptResult, McpError> {
    Ok(GetPromptResult {
        description: Some(format!("Code review for {}", args.language)),
        messages: vec![PromptMessage::new_text(PromptMessageRole::User, "...")],
    })
}
```

Return types: `Vec<PromptMessage>`, `GetPromptResult`, or `Result<T, McpError>`.

Client-side: `client.list_all_prompts().await?`, `client.get_prompt(GetPromptRequestParams { name, arguments, .. }).await?`.

### Sampling (reverse direction)

The server asks the client to perform an LLM completion via `context.peer.create_message(...)`. The client implements `ClientHandler::create_message()`.

```rust
let response = context.peer.create_message(CreateMessageRequestParams {
    messages: vec![SamplingMessage::user_text("...")],
    model_preferences: Some(ModelPreferences { /* hints, cost_priority, speed_priority, intelligence_priority */ }),
    system_prompt: Some("...".into()),
    include_context: Some(ContextInclusion::None),
    temperature: Some(0.7),
    max_tokens: 150,
    /* stop_sequences, metadata, tools, tool_choice */ ..
}).await?;
```

### Roots

`Root { uri, name }` — the URI of the client workspace (`file://...`). Server: `context.peer.list_roots().await?` + handle `on_roots_list_changed`. Client: implement `list_roots()` + `client.notify_roots_list_changed().await?` after changes.

### Logging

Server enable: `.enable_logging()`. Send: `context.peer.notify_logging_message(LoggingMessageNotificationParam { level, logger, data })`. Levels: `Debug`, `Info`, `Notice`, `Warning`, `Error`, `Critical`, `Alert`, `Emergency`. Client implements `on_logging_message()` + `client.set_level(SetLevelRequestParams { level: LoggingLevel::Warning, .. })`.

### Completions

Auto-complete for prompt/resource template arguments. Server: enable `.enable_completions()` + implement `complete()`. May use `request.context.get_argument(name)` for context-dependent suggestions.

### Notifications (fire-and-forget)

- **Progress:** `context.peer.notify_progress(ProgressNotificationParam { progress_token, progress, total, message })`.
- **Cancellation:** `context.peer.notify_cancelled(CancelledNotificationParam { request_id, reason })`; handle on the receiving side via `on_cancelled`.
- **Initialized:** sent automatically during the handshake; the server handles it via `on_initialized`.
- **List-changed:** `notify_tool_list_changed`, `notify_prompt_list_changed`, `notify_resource_list_changed`.

### Subscriptions

Capabilities: `.enable_resources().enable_resources_subscribe()`. Server implements `subscribe(SubscribeRequestParams)` + `unsubscribe(UnsubscribeRequestParams)`. Notify subscribers via `context.peer.notify_resource_updated(...)`.

### OAuth Support

Separate document: https://github.com/modelcontextprotocol/rust-sdk/blob/main/docs/OAUTH_SUPPORT.md. Relevant for M5 Consent Gateway.

## Configuration

| Cargo feature   | Purpose                                    |
| --------------- | ------------------------------------------ |
| `server`        | Server-side macros (`#[tool]`, `#[prompt]`) |
| `client`        | Client-side methods                        |

Both can be enabled together (typically for end-to-end testing).

## Best Practices

1. **For MyHealth-Europe — server-only.** `features = ["server"]` is sufficient; the client side is not needed.
2. **Tools — via macros.** `#[tool_router]` + `#[tool]` is cheaper than a manual implementation of `list_tools` + `call_tool`. Less boilerplate, automatic JSON schema from `schemars`.
3. **Description-arguments via `#[schemars(description = "...")]`** — the LLM client will see these texts in the tool catalog.
4. **Pin to a tagged version, not git-main.** Between minor versions the API of helper methods changes. First `version = "0.16"`, then pin to a concrete `=0.16.x`.
5. **Do not block the handler.** Everything is async; for CPU-heavy work — `tokio::task::spawn_blocking`.
6. **`waiting().await?` returns `QuitReason`** — use it in `main.rs` for graceful shutdown logic (Ctrl+C, SIGTERM).
7. **Error type — `rmcp::ErrorData as McpError`.** Standardize conversions from `myhealth-core::error::CoreError` via a `From` impl.
8. **Through the `Parameters<T>` wrapper** destructure tool parameters in the signature.

## Common Pitfalls

- **Migration to 1.x.** If you find examples with `version = "0.x"` where x<14 — the API is deprecated. Check the migration guide: https://github.com/modelcontextprotocol/rust-sdk/discussions/716
- **`#[tool_router(server_handler)]` vs `#[tool_handler]`.** The first is for a tools-only server, abbreviated; the second is for cases with custom metadata or multiple capabilities. Do not confuse them.
- **Resource URI format.** Must include a scheme (`file://`, `memo://`, `health://`). Without a scheme — `read_resource` returns 404.
- **Sampling is a client→LLM request.** The server has no model of its own; for autonomous reasoning the server must have its own LLM runtime, not use sampling.
- **Logging messages are notifications, not traces.** For server-internal observability use `tracing` (as fixed in the tech stack).
- **`enable_resources_subscribe()` without `enable_resources()`** — invalid configuration. Subscriptions are an extension of resources.

## Version Notes

- **MCP spec version target:** `2025-11-25` (current rmcp).
- Earlier the project's DESCRIPTION.md mentioned spec v0.6+. In modern MCP nomenclature the spec is numbered by dates, not semver. v0.6 ≈ overlap with `2025-06-18` or earlier; for the project, target `2025-11-25` as the baseline for `rmcp-0.16+`.
- Schema: https://github.com/modelcontextprotocol/specification/blob/main/schema/2025-11-25/schema.ts

## Integration with MyHealth-Europe

- **Crate:** `myhealth-mcp` — wrapper around the `rmcp` server.
- **PUBLIC API:** `McpServer::new(store: Arc<dyn RecordStore>, consent: Arc<ConsentGateway>, audit: Arc<dyn AuditSink>) -> Self` + `serve_stdio()` / `serve_sse()`.
- **Tools (MCP):** `get_observations`, `get_conditions`, `get_medications`, `get_allergies`, `get_immunizations`, `get_encounters`, `get_diagnostic_reports`, `search_records`, `get_health_summary` — read-only in phase 1.
- **Trust boundary:** before each `read_resource`/`call_tool` the handler calls `consent.validate(token, scope)` → blocked when denied → audit on grant/deny/read.
- **Transports:** `serve(stdio())` for desktop clients; SSE/HTTP — via a separate transport (optional in phase 1).
- **Capabilities:** `.enable_resources().enable_prompts()` are definitely needed; sampling/logging — for future phases.
