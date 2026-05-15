# MCP Rules

> Conventions for MCP tool handlers, resources, and prompts (`crates/myhealth-mcp/`).
> Loaded after `rules/base.md` for MCP-related code.

## Rules

- The MCP server is implemented through the official `rmcp` crate (by Anthropic). Third-party MCP implementations (`mcp-server-rs`, custom forks) are forbidden without an ADR.
- Compatibility with **MCP spec v0.6+**. Verified through the MCP Inspector test suite in CI (FR-3.1).
- All read-only MCP tools (FR-3.4) implement a single signature: `async fn(ctx: &McpCtx, params: Params) -> Result<ToolResponse, McpError>`. `McpCtx` carries `ConsentToken` + handles to `RecordStore`/`AuditSink`.
- **Every tool handler starts with `consent.verify(token, scope)?` — defense-in-depth on top of the Consent Gateway** (T-M3). Skipping the check here is a security bug even if the gateway already verified.
- Tool naming: `snake_case`, verb first — `get_observations`, `get_medications`, `get_health_summary`, `search_records`. `find_*`, `list_*`, `fetch_*` synonyms are forbidden — only `get_*` for read, `search_*` for query with filters.
- **Write-back operations are out of scope for phase 1** (FR-3.8). No `create_*`/`update_*`/`delete_*`/`patch_*` tool until an explicit M-pivot in phase 2.
- Phase 1 read-only surface (FR-3.4): `get_observations`, `get_conditions`, `get_medications`, `get_allergies`, `get_immunizations`, `get_encounters`, `get_diagnostic_reports`, `search_records`, `get_health_summary`. Extensions go through an ADR.
- `get_health_summary` (FR-3.5) returns a **structured overview without raw PHI**: counts by category, date ranges, source distribution. Used by agents for intelligent scope selection without presenting the full scope upfront.
- Tool results — JSON-serializable Rust types with `#[derive(Serialize)]`; never `serde_json::Value` as the return type in a public tool API.
- Tool errors are sanitized through `McpError::sanitize()` before return; no PHI in error messages even on `internal_error` (T-M4).
- **MCP data for the agent is marked as a `<data>` block**, not as free text; wrapping via `ToolResponse::data_block(...)` is mandatory — protection against prompt injection through FHIR free-text fields (T-M5).
- Transports (FR-3.2/FR-3.3): **`stdio` by default**, `SSE/HTTP` is opt-in via the flag `--transport=sse --bind=127.0.0.1:7777` with mandatory OAuth + TLS for non-localhost (T-M7).
- Resources (FR-3.6) live under the `health://` namespace: `health://schema/observation`, `health://schema/medication`, `health://examples/sample-observation`. Each resource is a `pub fn` in `crates/myhealth-mcp/src/resources/`.
- Prompts (FR-3.7) — pre-built reference prompts for `summary`, `medication-reconciliation`, `lab-trend`. Stored in `crates/myhealth-mcp/src/prompts/<name>.md` with frontmatter (`name`, `description`, `arguments`).
- **Per-agent rate limiting** — token bucket with default 60 req/min per `agent_id` (T-M6). Configurable via config; revoke on abuse.
- Tool query parameters are validated through `serde` + custom validators **before** `consent.verify()`; an invalid param → `McpError::invalid_params` without access to the store.
- Pagination is mandatory for `search_records` and any `get_*` that may return >100 records: `cursor` + `limit` (max 500). Missing pagination response → bug.
- Response timing is **constant-time** for permission denied vs not found (T-C6); leaky `time-of-check` → `time-of-use` patterns are forbidden.
- Each successful tool call → an audit event with `agent_id`, `tool_name`, `scope_used`, `record_count_returned`, **timestamp**, **token jti**. PHI body is not logged (T-L2).
- Each denied tool call → an audit event with reason (`scope_mismatch`, `token_revoked`, `rate_limited`, `invalid_params`).
- Unit tests for scope leakage: for each tool — a test that with a token whose scope is `read:observations:lab`, a request to `get_medications` → `McpError::forbidden` WITHOUT access to the store.
- MCP Inspector smoke test in CI on every PR that touches `crates/myhealth-mcp/`.
- Error codes follow JSON-RPC 2.0 spec: `-32602` invalid params, `-32603` internal, custom range `-32000..=-32099` for domain errors (`-32001` forbidden, `-32002` rate-limited, `-32003` token revoked).
- Handlers do not block the `tokio` runtime — all store reads via `async`, never `.blocking_read()`/`std::sync::Mutex`.
- Aggregator tools (`get_health_summary`) execute through a single store transaction (READ-only), not N+1 calls.
- A change to the tool surface (a new tool, a removal, a signature change) = breaking change → version bump + ADR + reference in `docs/02-prd.md`.
