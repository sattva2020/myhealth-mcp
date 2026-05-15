# Architecture: Modular Monolith + Hexagonal (Ports & Adapters)

## Overview

MyHealth-Europe is implemented as a **Modular Monolith** — a single Rust binary (or multi-stage Docker container) made of several independent crate-modules in a Cargo workspace, with an explicit public API per crate (`lib.rs`) and prohibitions on cross-module reach-in.

On top of modularity we layer the **Hexagonal (Ports & Adapters)** pattern: for FHIR importers, MCP transports, OAuth storage backends, and audit sinks we define **ports** (Rust traits in `myhealth-core`) and implement them as **adapters** (separate crates in `crates/adapters/*` or modules inside the domain-specific crates). This lets us add a new country (a new FHIR adapter) or a new MCP transport without touching the core, with full unit-test coverage via mock adapters.

Why this combination for **this** project:
- Single static binary <15 MB — core value prop for the Johann persona; microservices are architecturally excluded.
- 1 engineer + 1 part-time contributor — a modular monolith gives the speed of a monolith and module-boundary discipline, without the operational overhead of microservices.
- Trust boundaries (Consent Gateway → Store, MCP → Consent → Store) map naturally onto Hexagonal port boundaries — every trust boundary = one trait in `myhealth-core`.
- Future-extraction ready: if phase 2 ever requires extracting the Audit Log into a separate process for compliance reasons, the workspace structure makes it possible without refactoring the domain.

## Decision rationale

- **Project type:** Self-hosted MCP server for health data, single-binary deployment, multi-component (FHIR adapters / Local Store / MCP Server / Consent Gateway / Audit Log / UI Backend).
- **Tech stack:** Rust stable 1.80+, `tokio` async runtime, `axum`, `rmcp`, `rusqlite` + SQLCipher, `fhirbolt`.
- **Team size:** 1 engineer × 6 PM + 1 part-time contributor × 2 PM (FHIR adapters).
- **Domain complexity:** Medium-High (FHIR R4 schema, OAuth 2.1 with PKCE, encryption-at-rest, MCP protocol, untrusted-client model).
- **Scale:** Single user per deployment; horizontal scaling comes from replicating self-hosted instances, not shared infrastructure.
- **Key factor:** The architectural invariant "single static binary, no phone-home" requires a monolith. The plurality of independent adapters (FHIR sources, MCP transports) and the sharp trust boundaries require Hexagonal.

## Folder structure

```
myhealth-europe/
├── Cargo.toml                       # workspace root: [workspace] members + lints + profile
├── Cargo.lock                       # checked in (binary project)
├── rust-toolchain.toml              # pin Rust 1.80+ stable
│
├── crates/
│   ├── myhealth-core/               # Core domain (DEPENDENCIES: none, except serde)
│   │   ├── Cargo.toml
│   │   └── src/
│   │       ├── lib.rs               # PUBLIC API: re-exports from ports/, model/, error
│   │       ├── model/               # Domain types (FHIR-aligned, no serialization-specific code)
│   │       │   ├── mod.rs
│   │       │   ├── observation.rs
│   │       │   ├── medication.rs
│   │       │   ├── condition.rs
│   │       │   └── consent.rs       # ConsentToken, Scope, ResourceType
│   │       ├── ports/               # Hexagonal PORTS (traits)
│   │       │   ├── mod.rs
│   │       │   ├── fhir_importer.rs # trait FhirImporter
│   │       │   ├── store.rs         # trait RecordStore (read/write/query)
│   │       │   ├── consent_store.rs # trait ConsentStore (token storage)
│   │       │   ├── audit_sink.rs    # trait AuditSink (append-only)
│   │       │   └── mcp_transport.rs # trait McpTransport (stdio/SSE)
│   │       └── error.rs             # CoreError (thiserror enum)
│   │
│   ├── myhealth-store/              # ADAPTER for trait RecordStore (SQLite + SQLCipher)
│   │   └── src/
│   │       ├── lib.rs               # PUBLIC API: SqliteStore::open(path, passphrase)
│   │       ├── encryption/          # AES-GCM column-level encryption helpers
│   │       ├── migrations/          # Schema migrations (versioned, reversible)
│   │       ├── queries/             # Prepared statements per resource type
│   │       └── tests/               # Integration tests with real SQLCipher (no mocks)
│   │
│   ├── myhealth-mcp/                # MCP server (rmcp-based)
│   │   └── src/
│   │       ├── lib.rs               # PUBLIC API: McpServer::new(deps)
│   │       ├── tools/               # MCP tool handlers (get_observations, ...)
│   │       ├── resources/           # MCP resources (health://schema/*)
│   │       ├── prompts/             # MCP prompts (reference)
│   │       └── transports/          # ADAPTERS for trait McpTransport
│   │           ├── stdio.rs
│   │           └── sse.rs
│   │
│   ├── myhealth-consent/            # OAuth 2.1 Consent Gateway
│   │   └── src/
│   │       ├── lib.rs               # PUBLIC API: ConsentGateway::new(store, audit)
│   │       ├── oauth/               # OAuth 2.1 + PKCE flow
│   │       ├── token/               # JWT issuance/validation (HMAC-SHA256)
│   │       ├── scope/               # Scope parsing and matching
│   │       └── prompts/             # UI consent prompt API
│   │
│   ├── myhealth-audit/              # ADAPTER for trait AuditSink
│   │   └── src/
│   │       ├── lib.rs               # PUBLIC API: SqliteAuditSink, FileAuditSink
│   │       └── append_only.rs       # INSERT-only enforcement
│   │
│   ├── myhealth-ui/                 # axum UI backend (REST + WebSocket + htmx)
│   │   └── src/
│   │       ├── lib.rs               # PUBLIC API: UiServer::new(deps)
│   │       ├── routes/              # Route handlers
│   │       ├── templates/           # htmx server-rendered templates
│   │       └── static/              # Bundled assets (no external CDN)
│   │
│   ├── myhealth-cli/                # bin: myhealth import/backup/restore/...
│   │   └── src/
│   │       ├── main.rs              # Entry point; composition root
│   │       └── commands/            # Subcommands
│   │
│   └── adapters/                    # ADAPTERS for trait FhirImporter
│       ├── adapter-ua-nszu/         # eHealth UA (NSZU-FHIR)
│       │   └── src/lib.rs           # impl FhirImporter for UaNszuAdapter
│       ├── adapter-ee-digilugu/     # Estonia Digilugu (CDA→FHIR)
│       ├── adapter-apple/           # Apple Health (XML→FHIR)
│       └── adapter-generic-r4/      # Generic FHIR R4
│
├── installers/                      # tauri-bundler configs (.msi/.dmg/.AppImage/.deb)
├── docker/                          # Dockerfile (multi-stage), compose.yml
├── docs/                            # Pre-implementation documentation + ADRs
│   └── adr/                         # Architecture Decision Records
└── tests/                           # Cross-crate integration tests + benchmarks
    ├── e2e/                         # End-to-end flows (import → consent → MCP read)
    ├── property/                    # proptest for FHIR/OAuth/encryption
    └── benches/                     # criterion benchmarks (NFR-P1: p99 <200 ms)
```

## Dependency rules

The Cargo workspace enforces these via `[dependencies]` sections; they are additionally checked by a `cargo-deny` rule and during review.

**Allowed (✅):**

- ✅ `myhealth-core` → nothing from the workspace (only std + serde + thiserror)
- ✅ `myhealth-store` → `myhealth-core` (impl trait RecordStore + ConsentStore)
- ✅ `myhealth-audit` → `myhealth-core` (impl trait AuditSink)
- ✅ `myhealth-consent` → `myhealth-core`, `myhealth-audit`
- ✅ `myhealth-mcp` → `myhealth-core`, `myhealth-store`, `myhealth-consent`, `myhealth-audit`
- ✅ `myhealth-ui` → `myhealth-core`, `myhealth-store`, `myhealth-consent`, `myhealth-audit`
- ✅ `crates/adapters/*` → **only** `myhealth-core` (impl trait FhirImporter)
- ✅ `myhealth-cli` → all crates (composition root)

**Forbidden (❌):**

- ❌ `myhealth-core` → any other workspace crate
- ❌ `crates/adapters/*` → `myhealth-store`, `myhealth-mcp`, `myhealth-consent`, `myhealth-audit`, `myhealth-ui`
- ❌ Adapter → another adapter (`adapter-ua-nszu` → `adapter-ee-digilugu`)
- ❌ Any crate → internal modules of another crate (anything beyond the `lib.rs` API)
- ❌ `myhealth-mcp` → `myhealth-ui` (MCP does not depend on UI)
- ❌ `myhealth-ui` → `myhealth-mcp` (UI does not require the MCP stack to launch the setup wizard)
- ❌ Cycle: `A → B → A` of any length

## Layer/module communication

- **Through trait objects from `myhealth-core::ports`.** Higher-level crates do not know concrete impls (e.g. `ConsentGateway` accepts `Arc<dyn AuditSink>`, not `Arc<SqliteAuditSink>`).
- **Composition root — `myhealth-cli/src/main.rs`.** This is the single place where concrete adapters are wired into trait objects and passed into `McpServer::new(...)`, `ConsentGateway::new(...)`, `UiServer::new(...)`.
- **Async via `tokio` channels** (`mpsc`/`broadcast`) for cross-component notifications (e.g. audit events → UI WebSocket).
- **Domain events** — `myhealth-core::events::DomainEvent` enum; emitted by the consent gateway, consumed by the UI (for live notifications) and by audit (for recording).
- **No global state.** No `static mut` or `lazy_static!` for shared state. All dependencies are injected through constructors.
- **Helper script for boundary checking:** `scripts/check-deps.sh` parses `Cargo.toml` of all crates and fails if it finds a forbidden dependency.

## Key principles

1. **Hard module boundaries — `lib.rs` as the single entry point.** All public types and functions are re-exported from `lib.rs`. Internal modules (`mod foo;`) are `pub(crate)`, not `pub`.
2. **Domain crate `myhealth-core` is pure.** No I/O, no async runtime, no serde on REST-API types. Only FHIR-aligned models, ports/traits, errors.
3. **Hexagonal: traits in `core`, impls in adapters.** Each adapter (FHIR source, MCP transport, audit sink, store backend) is a separate crate or subdirectory with a single trait impl.
4. **One composition root — `myhealth-cli/src/main.rs`.** No library crate creates "default" instances of its dependencies.
5. **Trust boundaries = port boundaries.** Every trust boundary (UI ↔ Consent, MCP ↔ Consent, Consent ↔ Store, Anything ↔ Audit) is a separate trait in `myhealth-core::ports`.
6. **Crate-local errors via `thiserror`.** No `Box<dyn Error>` in any public API except `myhealth-cli`. Conversions are done via `From` impls in the wrapper crates.
7. **No `unsafe` without an ADR.** An `unsafe` block is allowed only when tied to a specific ADR in `docs/adr/`.
8. **Test pyramid: unit (per crate) → property (`proptest`) → integration (`tests/e2e/`) → bench (`tests/benches/`).** Each port has a mock impl in `myhealth-core::testing` (feature-flag `testing`) for unit tests of higher-level crates.

## Code examples

### Example 1 — Port (trait) in `myhealth-core`

```rust
// crates/myhealth-core/src/ports/fhir_importer.rs

use crate::error::CoreError;
use crate::model::{ImportSummary, RawBundle};
use async_trait::async_trait;

/// Port: parse a FHIR bundle from a specific source format and
/// return a normalized list of domain records plus an import summary.
///
/// Implementations live in `crates/adapters/*` and depend ONLY on `myhealth-core`.
#[async_trait]
pub trait FhirImporter: Send + Sync {
    /// Stable identifier for the audit log (e.g. "ua-nszu", "ee-digilugu").
    fn source_id(&self) -> &'static str;

    /// Parse + normalize. PHI never leaks into CoreError.
    async fn import(&self, bundle: RawBundle) -> Result<ImportSummary, CoreError>;
}
```

### Example 2 — Adapter (trait impl) in `crates/adapters/adapter-ee-digilugu/`

```rust
// crates/adapters/adapter-ee-digilugu/src/lib.rs

use myhealth_core::error::CoreError;
use myhealth_core::model::{ImportSummary, RawBundle};
use myhealth_core::ports::FhirImporter;
use async_trait::async_trait;

pub struct DigiluguAdapter {
    // adapter-private state (CDA→FHIR mappers, validators)
}

impl DigiluguAdapter {
    pub fn new() -> Self {
        Self { /* ... */ }
    }
}

#[async_trait]
impl FhirImporter for DigiluguAdapter {
    fn source_id(&self) -> &'static str {
        "ee-digilugu"
    }

    async fn import(&self, bundle: RawBundle) -> Result<ImportSummary, CoreError> {
        // 1. CDA→FHIR transform (legacy records)
        // 2. Schema validation against FHIR R4
        // 3. Idempotency check (FR-1.5)
        // 4. Build ImportSummary without PHI in Display/Debug
        todo!()
    }
}
```

### Example 3 — Composition root in `myhealth-cli/src/main.rs`

```rust
// crates/myhealth-cli/src/main.rs

use std::sync::Arc;

use myhealth_core::ports::{AuditSink, ConsentStore, FhirImporter, RecordStore};
use myhealth_consent::ConsentGateway;
use myhealth_mcp::McpServer;
use myhealth_store::SqliteStore;
use myhealth_audit::SqliteAuditSink;
use adapter_ua_nszu::UaNszuAdapter;
use adapter_ee_digilugu::DigiluguAdapter;
use adapter_apple::AppleHealthAdapter;
use adapter_generic_r4::GenericR4Adapter;
use secrecy::SecretString;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let passphrase = read_passphrase_securely()?;

    // Single concrete impl per port — wired here.
    let store: Arc<dyn RecordStore> = Arc::new(SqliteStore::open("data.db", &passphrase).await?);
    let consent_store: Arc<dyn ConsentStore> = Arc::clone(&store).as_consent_store();
    let audit: Arc<dyn AuditSink> = Arc::new(SqliteAuditSink::open("audit.db").await?);

    let importers: Vec<Arc<dyn FhirImporter>> = vec![
        Arc::new(UaNszuAdapter::new()),
        Arc::new(DigiluguAdapter::new()),
        Arc::new(AppleHealthAdapter::new()),
        Arc::new(GenericR4Adapter::new()),
    ];

    let consent = Arc::new(ConsentGateway::new(consent_store, Arc::clone(&audit)));
    let mcp = McpServer::new(Arc::clone(&store), Arc::clone(&consent), Arc::clone(&audit));

    mcp.serve_stdio().await?;
    Ok(())
}

fn read_passphrase_securely() -> anyhow::Result<SecretString> {
    todo!("rpassword or platform keychain")
}
```

### Example 4 — Forbidden cross-module reach-in (DO NOT do)

```rust
// ❌ FORBIDDEN: pulling an internal module of another crate
use myhealth_store::encryption::derive_key; // pub(crate), not pub — compile error
use myhealth_consent::token::sign_jwt;       // same

// ❌ FORBIDDEN: an adapter depending on the store
// crates/adapters/adapter-ee-digilugu/Cargo.toml
[dependencies]
myhealth-core = { path = "../../myhealth-core" }
myhealth-store = { path = "../../myhealth-store" }   # ← Forbidden!

// ❌ FORBIDDEN: prod code panicking
let token = consent.issue(&scope).unwrap(); // .unwrap() forbidden in production path
```

### Example 5 — Mock port for a unit test (`myhealth-core::testing`)

```rust
// crates/myhealth-core/src/testing/mod.rs (feature = "testing")

use crate::ports::AuditSink;
use crate::model::AuditEvent;
use crate::error::CoreError;
use async_trait::async_trait;
use std::sync::{Arc, Mutex};

#[derive(Default, Clone)]
pub struct InMemoryAuditSink {
    events: Arc<Mutex<Vec<AuditEvent>>>,
}

impl InMemoryAuditSink {
    pub fn events(&self) -> Vec<AuditEvent> {
        self.events.lock().unwrap().clone()
    }
}

#[async_trait]
impl AuditSink for InMemoryAuditSink {
    async fn append(&self, event: AuditEvent) -> Result<(), CoreError> {
        self.events.lock().unwrap().push(event);
        Ok(())
    }
}
```

## Anti-patterns

- ❌ **Reach-in via `pub` for convenience** — if you find yourself wanting `pub use crate::store::encryption::derive_key`, you need a new port in `myhealth-core`.
- ❌ **An adapter knowing about another adapter** — `adapter-ua-nszu` never imports `adapter-ee-digilugu`. Common logic lives in `myhealth-core`.
- ❌ **`myhealth-core` pulling in `tokio`/`axum`/`rusqlite`** — the domain crate must be runtime-agnostic. Async traits go through `async_trait` (zero-cost for trait objects).
- ❌ **Global state (`lazy_static!`, `OnceCell`) for dependencies** — everything via DI in the composition root.
- ❌ **Cyclic dependency (A → B → A)** — refactor it into a shared `myhealth-core` type.
- ❌ **PHI in `Display`/`Debug` for domain types** — use redacted `#[derive(Debug)]` via `secrecy` or a custom impl that hides the body.
- ❌ **`.unwrap()` / `.expect()` in production paths** (including `?` on `Option` without reason). Allowed only in tests and in `main.rs` for startup config.
- ❌ **Splitting the Audit Log into a separate process in phase 1** — even when tempted. The Modular Monolith is ready for extraction, but phase 1 deployment is a single binary.
- ❌ **Skip-layer calls** — a UI handler never calls `SqliteStore` directly, only via the `RecordStore` trait, and only after going through the Consent Gateway where appropriate.
- ❌ **Creating `Arc<dyn Trait>` outside the composition root** — library-crate constructors accept already-wired trait objects.
