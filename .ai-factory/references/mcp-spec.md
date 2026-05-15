# MCP Wire Protocol Reference

> Source: https://modelcontextprotocol.io/specification/2025-11-25, https://github.com/modelcontextprotocol/specification/blob/main/schema/2025-11-25/schema.ts (normative TypeScript schema), https://github.com/modelcontextprotocol/rust-sdk (README with a complete example of all MCP operations)
> Created: 2026-05-12
> Updated: 2026-05-12
> Protocol version target: **2025-11-25**

## Overview

Model Context Protocol (MCP) is a JSON-RPC 2.0-based wire protocol for connecting LLM agents (clients) with servers that provide **tools**, **resources**, and **prompts**. Developed by Anthropic, with an open specification. The current normative version is `LATEST_PROTOCOL_VERSION = "2025-11-25"`, `JSONRPC_VERSION = "2.0"`.

MCP describes **two roles**:

- **Server** — exposes primitives (tools/resources/prompts/sampling/roots/logging/completions).
- **Client** — consumes primitives; the LLM runs on the client side.

The two roles are mutually symmetric in how they send and receive JSON-RPC requests and notifications.

## Core Concepts

### JSON-RPC envelope

All messages are `JSONRPCMessage`:

```ts
export type JSONRPCMessage =
  | JSONRPCRequest
  | JSONRPCNotification
  | JSONRPCResponse;
```

- `JSONRPCRequest` — expects a response (request_id is mandatory)
- `JSONRPCNotification` — fire-and-forget, no response (`method` + optional `params`)
- `JSONRPCResponse` — `{id, result}` or `{id, error}`

### Common types

```ts
export type ProgressToken = string | number;  // token for progress notifications
export type Cursor = string;                    // opaque cursor for pagination
```

### RequestParams._meta

Every request can include a `_meta` field for out-of-band metadata, including `progressToken`:

```ts
export interface RequestParams {
  _meta?: {
    progressToken?: ProgressToken;
    [key: string]: unknown;
  };
}
```

### Task-augmented requests

Some requests can be executed asynchronously (the server returns `CreateTaskResult` immediately, the actual result arrives later via `tasks/result`). This is capability-negotiated; the server must explicitly declare support.

```ts
export interface TaskAugmentedRequestParams extends RequestParams {
  task?: TaskMetadata;
}
```

## Lifecycle

1. **Handshake.** The client first sends an `initialize` request with its capabilities. The server responds with its capabilities + protocol version.
2. **Initialized notification.** The client confirms successful init via `notifications/initialized`. The server may accept requests after this.
3. **Normal operation.** Requests/notifications flow in both directions.
4. **Shutdown.** Either by closing the transport, or via `notifications/cancelled` with the appropriate reason.

In `rmcp`, this lifecycle is wrapped in `serve(transport).await?` → `waiting().await?` (blocks until shutdown).

## Capabilities

The server and client declare their capabilities in `initialize`. Server-side capabilities (via `ServerCapabilities`):

| Capability                | What it provides                                            |
| ------------------------- | ----------------------------------------------------------- |
| `tools`                   | Server can expose callable functions                        |
| `resources`               | Server can expose data behind URIs                          |
| `resources.subscribe`     | Resources support subscriptions to updates                  |
| `resources.listChanged`   | Server sends `notifications/resources/list_changed`         |
| `prompts`                 | Server exposes reusable message templates                   |
| `prompts.listChanged`     | Server sends `notifications/prompts/list_changed`           |
| `logging`                 | Server sends structured log messages to the client          |
| `completions`             | Server provides autocomplete for prompt/resource template args |

Client-side capabilities:

| Capability                | What it provides                                            |
| ------------------------- | ----------------------------------------------------------- |
| `roots`                   | Client exposes workspace URIs                               |
| `roots.listChanged`       | Client sends notify when roots change                       |
| `sampling`                | Client is ready to handle `sampling/create_message` from the server |

## MCP Primitives

### Tools

The server exposes callable functions. Each tool has:

- `name: string` — unique identifier
- `description: string` — human-readable description (the LLM reads it when selecting)
- `inputSchema: JSONSchema` — formal parameter schema (JSON Schema 2020-12)

**Operations:**

| Method        | Direction        | Purpose                                                           |
| ------------- | ---------------- | ----------------------------------------------------------------- |
| `tools/list`  | client → server | List of available tools (paginated via `cursor`)                  |
| `tools/call`  | client → server | Invocation of a specific tool by `name` + `arguments`             |
| `notifications/tools/list_changed` | server → client | Tools list updated; client must re-fetch     |

`CallToolResult` contains `content: Vec<ContentBlock>` (text/image/resource_link), `isError: bool`.

### Resources

The server exposes readable data behind URIs. The URI MUST have a scheme (`file://`, `memo://`, `health://`, custom).

**Operations:**

| Method                           | Direction        | Purpose                                           |
| -------------------------------- | ---------------- | ------------------------------------------------- |
| `resources/list`                 | client → server | List of available resources (paginated)           |
| `resources/templates/list`       | client → server | Resource templates with URI patterns              |
| `resources/read`                 | client → server | Read a specific resource by URI                   |
| `resources/subscribe`            | client → server | Subscribe to resource updates                     |
| `resources/unsubscribe`          | client → server | Unsubscribe                                       |
| `notifications/resources/list_changed` | server → client | Resources list updated                       |
| `notifications/resources/updated` | server → client | A specific resource updated (for subscribers)   |

`ReadResourceResult` contains `contents: Vec<ResourceContents>` (text or base64 binary).

### Prompts

Reusable message templates with typed arguments.

**Operations:**

| Method                          | Direction        | Purpose                                                |
| ------------------------------- | ---------------- | ------------------------------------------------------ |
| `prompts/list`                  | client → server | List of available prompts                              |
| `prompts/get`                   | client → server | Retrieve a prompt by name + arguments                  |
| `notifications/prompts/list_changed` | server → client | Prompts list updated                              |

`GetPromptResult`:

```ts
{
  description?: string,
  messages: Vec<PromptMessage>  // { role: User|Assistant, content: ContentBlock }
}
```

### Sampling (reverse direction: server → client → LLM)

The server asks the client to perform an LLM completion. Unique in that this is the only primitive where the requesting side is the server.

**Operation:** `sampling/create_message` (server → client).

Params:

```ts
{
  messages: Vec<SamplingMessage>,
  modelPreferences?: {
    hints?: Vec<ModelHint>,
    costPriority?: number,           // 0..1
    speedPriority?: number,          // 0..1
    intelligencePriority?: number    // 0..1
  },
  systemPrompt?: string,
  includeContext?: "none" | "thisServer" | "allServers",
  temperature?: number,
  maxTokens: number,
  stopSequences?: Vec<string>,
  metadata?: object
}
```

The client implements `create_message()`, forwards it to its LLM, and returns `CreateMessageResult`.

### Roots

The client declares its workspace URIs (typically `file://`-prefixed paths).

**Operations:**

| Method                          | Direction        | Purpose                                      |
| ------------------------------- | ---------------- | -------------------------------------------- |
| `roots/list`                    | server → client | Server asks the client about its roots       |
| `notifications/roots/list_changed` | client → server | Client notifies that roots updated      |

### Logging

Structured log messages from the server to the client.

**Operations:**

| Method                          | Direction        | Purpose                                  |
| ------------------------------- | ---------------- | ---------------------------------------- |
| `logging/setLevel`              | client → server | Client sets the minimum level            |
| `notifications/message`         | server → client | Server sends a log event to the client   |

Levels (from least to most severe): `debug`, `info`, `notice`, `warning`, `error`, `critical`, `alert`, `emergency`.

### Completions

Auto-complete for prompt/resource-template arguments.

**Operation:** `completion/complete` (client → server). The server returns `CompleteResult.completion.values: Vec<string>`. It may use `request.context.arguments` (previously filled arguments) for context-dependent suggestions.

### Notifications (general)

| Method                          | Direction         | Purpose                                      |
| ------------------------------- | ----------------- | -------------------------------------------- |
| `notifications/initialized`     | client → server  | After the handshake                          |
| `notifications/progress`        | server → client  | Progress of a long operation by `progressToken` |
| `notifications/cancelled`       | bidirectional    | Cancellation of a request                    |

## Transports

The transport layer is a separate responsibility. The MCP specification does not mandate a specific one; it declares only that this is a duplex stream of JSON-RPC messages.

**Standard transports:**

- **stdio** — most common. The server process reads stdin and writes stdout. One process — one server.
- **HTTP/SSE** — for remote servers. The client opens an SSE channel for server-push notifications and sends requests via POST.
- **Streamable HTTP** — new, replaces legacy SSE; bidirectional through keep-alive.

In rmcp: the `stdio()` helper or a tuple `(reader, writer)` for a custom transport.

## Authorization

The MCP spec 2025-11-25 contains a separate Authorization section. Concrete details (DCR, OAuth 2.1, PKCE flow) require a separate reference (`oauth-2.1-pkce.md`).

Key points:

- MCP servers that require auth typically use **OAuth 2.1 + PKCE** for the browser flow.
- The token is `Bearer` in the `Authorization` header (for HTTP transport).
- Scope-by-resource-type — described in the MCP documentation as a best practice for fine-grained access to specific tools/resources.

## Configuration / Capability Negotiation

Capability negotiation happens in `initialize`:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {
    "protocolVersion": "2025-11-25",
    "capabilities": {
      "roots": { "listChanged": true },
      "sampling": {}
    },
    "clientInfo": { "name": "claude-desktop", "version": "1.x.x" }
  }
}
```

The server responds analogously with its own capabilities. The side that received capabilities from the other is REQUIRED not to use features the other side did not declare.

## Best Practices

1. **Always declare capabilities explicitly.** Do not rely on "defaults" — that will produce 500 errors in clients.
2. **Tool descriptions are for the LLM, not for developers.** The LLM uses `description` when selecting. Write imperatively and concretely: "Get a patient's lab observations within a date range", not "get_observations function".
3. **JSON Schema 2020-12** for tool input — this is the spec-mandated version. `schemars` generates exactly this by default.
4. **URI scheme is reserved.** For a medical context — `health://schema/<resource-type>` or a custom scheme is suggested, not `file://`.
5. **Paginate `list_*` operations.** Cursors exist for exactly this; for 10,000+ records it is mandatory.
6. **Subscriptions are for dynamic resources.** Stable files do not need subscribe — a regular `read` is sufficient.
7. **Progress notifications only when the client has sent `progressToken`.** Otherwise the client ignores them.
8. **Errors via the standard JSON-RPC error envelope.** Custom error codes from -32000 to -32099.

## Common Pitfalls

- **Plain method without `notifications/` prefix.** If you send a request without `id` it is a notification, but the method must start with `notifications/`. Otherwise the receiver treats it as malformed.
- **`tools/call` without a prior `tools/list`.** Technically possible, but the client will not know the tool. Always `list` → user picks → `call`.
- **Sampling without client capability.** If the client did not declare `sampling`, server `create_message` will return an error.
- **Resource URI without scheme.** Invalid; `resources/read` will return 404 or a malformed error.
- **Unreleased subscriptions.** If the client does not call `unsubscribe` before closing — leak on the server side. The server must clean up on transport disconnect.
- **Protocol version mismatch.** If the client claims `2024-11-05` and the server only supports `2025-11-25` — handshake fails. Support several versions or return a clear error.

## Version Notes

- **2025-11-25** — current baseline for `rmcp 0.16+`.
- **2025-06-18** — previous version. Main changes: introduction of tasks/result async pattern, refined OAuth 2.1 authorization spec.
- **Legacy SSE transport** will be deprecated in favor of Streamable HTTP. In phase 1 of the project — start with stdio, add Streamable HTTP later.
- Schema file: https://github.com/modelcontextprotocol/specification/blob/main/schema/2025-11-25/schema.ts — the mandatory source of truth in case of doubts about message format.

## Integration with MyHealth-Europe

- **Crate `myhealth-mcp`** — wrapper around `rmcp`. Exposes `McpServer::new(...)`.
- **Tools that are exposed** (M4): `get_observations`, `get_conditions`, `get_medications`, `get_allergies`, `get_immunizations`, `get_encounters`, `get_diagnostic_reports`, `search_records`, `get_health_summary`. All read-only in phase 1.
- **Resources schema:** `health://schema/<resource-type>` — descriptions of FHIR models, no PHI.
- **Prompts:** optional (for example, a prompt template for cross-border summary HealBot.pro).
- **Authorization:** OAuth 2.1 + PKCE via a separate Consent Gateway (M5). Token validation is mounted into `myhealth-mcp` via middleware.
- **Capability set:** `tools` + `resources` (without subscribe in phase 1) + `prompts` optional. No `logging` on the client side (the server keeps `tracing` locally).
- **No sampling.** Not used — it increases the attack surface (untrusted-client model).
