# Архітектура: Modular Monolith + Hexagonal (Ports & Adapters)

## Огляд

MyHealth-Europe реалізується як **Modular Monolith** — єдиний Rust-binary (або multi-stage Docker container), що складається з кількох незалежних crate-модулів у Cargo workspace, з explicit публічним API кожного crate (`lib.rs`) і заборонами на cross-module reach-in.

Поверх модульності накладається **Hexagonal (Ports & Adapters)** патерн: для FHIR-імпортерів, MCP-транспортів, OAuth-storage backends, audit-sinks ми визначаємо **порти** (Rust traits у `myhealth-core`) і реалізуємо їх як **адаптери** (окремі crates у `crates/adapters/*` або модулі у профільних crates). Це дозволяє додавати нову країну (новий FHIR-адаптер) або новий MCP-транспорт без змін у ядрі та з повним unit-test покриттям через mock-адаптери.

Чому ця комбінація для **цього** проекту:
- Single static binary <15MB — core value prop для Йоганн-persona; microservices виключені архітектурно.
- 1 engineer + 1 part-time contributor — модульний моноліт дає швидкість моноліту і дисципліну меж модулів, без operational overhead мікросервісів.
- Trust boundaries (Consent Gateway → Store, MCP → Consent → Store) природно лягають на Hexagonal port boundaries — кожна границя довіри = окремий trait у `myhealth-core`.
- Future-extraction ready: якщо у phase 2 знадобиться винести Audit Log у окремий процес для compliance — workspace-структура це дозволяє без рефакторингу домену.

## Decision Rationale

- **Project type:** Self-hosted MCP-сервер для health-даних, single-binary deployment, multi-component (FHIR adapters / Local Store / MCP Server / Consent Gateway / Audit Log / UI Backend).
- **Tech stack:** Rust stable 1.80+, `tokio` async runtime, `axum`, `rmcp`, `rusqlite` + SQLCipher, `fhirbolt`.
- **Team size:** 1 engineer × 6 PM + 1 part-time contributor × 2 PM (FHIR-адаптери).
- **Domain complexity:** Medium-High (FHIR R4 schema, OAuth 2.1 з PKCE, encryption-at-rest, MCP protocol, untrusted-client model).
- **Scale:** Single-user per deployment; horizontal scaling — за рахунок replicating self-hosted instances, не shared infra.
- **Key factor:** Архітектурний інваріант "single static binary, no phone-home" вимагає monolith. Множина незалежних адаптерів (FHIR sources, MCP transports) і чіткі trust boundaries вимагають Hexagonal.

## Folder Structure

```
myhealth-europe/
├── Cargo.toml                       # workspace root: [workspace] members + lints + profile
├── Cargo.lock                       # checked in (бінарний проект)
├── rust-toolchain.toml              # pin Rust 1.80+ stable
│
├── crates/
│   ├── myhealth-core/               # Core domain (DEPENDENCIES: none, крім serde)
│   │   ├── Cargo.toml
│   │   └── src/
│   │       ├── lib.rs               # PUBLIC API: re-exports з ports/, model/, error
│   │       ├── model/               # Domain types (FHIR-aligned, без serialization-specific)
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
│   │       └── tests/               # Integration tests з real SQLCipher (без mocks)
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
│   │       ├── scope/               # Scope parsing і matching
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
├── docs/                            # Pre-implementation документація + ADRs
│   └── adr/                         # Architecture Decision Records
└── tests/                           # Cross-crate integration tests + benchmarks
    ├── e2e/                         # End-to-end flows (import → consent → MCP read)
    ├── property/                    # proptest для FHIR/OAuth/encryption
    └── benches/                     # criterion benchmarks (NFR-P1: p99 <200ms)
```

## Dependency Rules

Cargo workspace enforce-ить через `[dependencies]` секції; додатково перевіряється `cargo-deny`-rule і review.

**Дозволено (✅):**

- ✅ `myhealth-core` → нічого з workspace (тільки std + serde + thiserror)
- ✅ `myhealth-store` → `myhealth-core` (impl trait RecordStore + ConsentStore)
- ✅ `myhealth-audit` → `myhealth-core` (impl trait AuditSink)
- ✅ `myhealth-consent` → `myhealth-core`, `myhealth-audit`
- ✅ `myhealth-mcp` → `myhealth-core`, `myhealth-store`, `myhealth-consent`, `myhealth-audit`
- ✅ `myhealth-ui` → `myhealth-core`, `myhealth-store`, `myhealth-consent`, `myhealth-audit`
- ✅ `crates/adapters/*` → **тільки** `myhealth-core` (impl trait FhirImporter)
- ✅ `myhealth-cli` → усі crates (composition root)

**Заборонено (❌):**

- ❌ `myhealth-core` → будь-який інший workspace crate
- ❌ `crates/adapters/*` → `myhealth-store`, `myhealth-mcp`, `myhealth-consent`, `myhealth-audit`, `myhealth-ui`
- ❌ Адаптер → інший адаптер (`adapter-ua-nszu` → `adapter-ee-digilugu`)
- ❌ Будь-який crate → внутрішні модулі іншого crate (не `lib.rs`-API)
- ❌ `myhealth-mcp` → `myhealth-ui` (MCP не залежить від UI)
- ❌ `myhealth-ui` → `myhealth-mcp` (UI не вимагає MCP-stack для запуску setup wizard)
- ❌ Cycle: `A → B → A` будь-якої довжини

## Layer/Module Communication

- **Через trait objects з `myhealth-core::ports`.** Higher-level crates не знають конкретні impl-и (наприклад, `ConsentGateway` приймає `Arc<dyn AuditSink>`, не `Arc<SqliteAuditSink>`).
- **Composition root — `myhealth-cli/src/main.rs`.** Тут єдине місце, де конкретні адаптери wired у trait objects і передаються у `McpServer::new(...)`, `ConsentGateway::new(...)`, `UiServer::new(...)`.
- **Async через `tokio` channels** (`mpsc`/`broadcast`) для cross-component notifications (наприклад, audit-events → UI WebSocket).
- **Domain events** — `myhealth-core::events::DomainEvent` enum; emit-ить consent gateway, споживає UI (для live notifications) і audit (для запису).
- **No global state.** Жодного `static mut`, `lazy_static!` для shared state. Усі залежності injecting through constructors.
- **Helper script для перевірки meж:** `scripts/check-deps.sh` парсить `Cargo.toml` усіх crates і fail-ить, якщо знайдено заборонену залежність.

## Key Principles

1. **Hard module boundaries — `lib.rs` як єдиний entry point.** Усі публічні типи/функції re-export-яться з `lib.rs`. Внутрішні модулі (`mod foo;`) — `pub(crate)`, не `pub`.
2. **Domain crate `myhealth-core` — pure.** Без I/O, без async runtime, без serde на rest-API типах. Тільки FHIR-aligned моделі, ports-traits, errors.
3. **Hexagonal: traits у `core`, impl-и в адаптерах.** Кожен adapter (FHIR source, MCP transport, audit sink, store backend) — окремий crate або subdirectory з єдиним trait impl.
4. **Composition root один — `myhealth-cli/src/main.rs`.** Жоден crate-бібліотека не створює "default" instances своїх dependencies.
5. **Trust boundaries = port boundaries.** Кожна границя довіри (UI ↔ Consent, MCP ↔ Consent, Consent ↔ Store, Anything ↔ Audit) — окремий trait у `myhealth-core::ports`.
6. **Errors crate-local через `thiserror`.** Жодного `Box<dyn Error>` у public API крім `myhealth-cli`. Конверсії — через `From` impl у каркасних crates.
7. **No `unsafe` без ADR.** `unsafe` блок дозволено тільки з прив'язкою до конкретного ADR у `docs/adr/`.
8. **Test pyramid: unit (per crate) → property (`proptest`) → integration (`tests/e2e/`) → bench (`tests/benches/`).** Кожен port має mock impl у `myhealth-core::testing` (feature-flag `testing`) для unit-тестів higher-level crates.

## Code Examples

### Приклад 1 — Port (trait) у `myhealth-core`

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
    /// Stable identifier для аудит-логу (наприклад, "ua-nszu", "ee-digilugu").
    fn source_id(&self) -> &'static str;

    /// Parse + normalize. PHI ніколи не потрапляє у CoreError.
    async fn import(&self, bundle: RawBundle) -> Result<ImportSummary, CoreError>;
}
```

### Приклад 2 — Adapter (trait impl) у `crates/adapters/adapter-ee-digilugu/`

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
        // 2. Schema validation проти FHIR R4
        // 3. Idempotency check (FR-1.5)
        // 4. Build ImportSummary без PHI у Display/Debug
        todo!()
    }
}
```

### Приклад 3 — Composition root у `myhealth-cli/src/main.rs`

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
    todo!("rpassword або platform keychain")
}
```

### Приклад 4 — Заборонена cross-module reach-in (НЕ робити)

```rust
// ❌ ЗАБОРОНЕНО: тягнути внутрішній модуль чужого crate
use myhealth_store::encryption::derive_key; // pub(crate), не pub — compile error
use myhealth_consent::token::sign_jwt;       // те саме

// ❌ ЗАБОРОНЕНО: adapter залежить від store
// crates/adapters/adapter-ee-digilugu/Cargo.toml
[dependencies]
myhealth-core = { path = "../../myhealth-core" }
myhealth-store = { path = "../../myhealth-store" }   # ← Forbidden!

// ❌ ЗАБОРОНЕНО: prod код панікує
let token = consent.issue(&scope).unwrap(); // .unwrap() заборонений у production path
```

### Приклад 5 — Mock-port для unit-тесту (`myhealth-core::testing`)

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

## Anti-Patterns

- ❌ **Reach-in через `pub` для зручності** — якщо хочеться `pub use crate::store::encryption::derive_key`, значить треба новий port у `myhealth-core`.
- ❌ **Adapter знає про інший adapter** — `adapter-ua-nszu` ніколи не імпортує `adapter-ee-digilugu`. Common логіку — у `myhealth-core`.
- ❌ **`myhealth-core` тягне `tokio`/`axum`/`rusqlite`** — domain crate має бути runtime-agnostic. Async traits — через `async_trait` (zero-cost для trait objects).
- ❌ **Global state (`lazy_static!`, `OnceCell`) для dependencies** — усе через DI у composition root.
- ❌ **Циклічна залежність (A → B → A)** — рефакторити у спільний `myhealth-core` тип.
- ❌ **PHI у `Display`/`Debug` для domain types** — використовувати редактовані `#[derive(Debug)]` через `secrecy` або custom impl, що ховає тіло.
- ❌ **`.unwrap()` / `.expect()` у production path** (включаючи `?` на `Option` без причини). Дозволено тільки у тестах і у `main.rs` для startup config.
- ❌ **Виносити Audit Log у окремий процес у phase 1** — навіть якщо хочеться. Modular Monolith готовий до extraction, але phase 1 deployment — single binary.
- ❌ **Skip-layer виклики** — UI handler ніколи не дзвонить `SqliteStore` напряму, тільки через `RecordStore` trait, і тільки після проходження через Consent Gateway де доречно.
- ❌ **Створювати `Arc<dyn Trait>` поза composition root** — конструктори бібліотечних crates приймають вже готові trait objects.
