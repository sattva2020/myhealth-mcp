# 06 — Architecture

**Document:** MyHealth-Europe — system architecture, components, deployment topology
**Version:** 0.1
**Date:** 2026-05-12
**Owner:** Ruslan Hryban

---

## TL;DR (for the review committee)

The system consists of six components that run in a single process (or a single Docker container) on the user's device: (1) the Adapter Layer for importing FHIR from sources, (2) the Local Store for encrypted storage, (3) the MCP Server as the interface to AI agents, (4) the Consent Gateway as an OAuth gatekeeper, (5) the Audit Log as a continuous journal, and (6) the UI Backend and UI Frontend as the user-facing layer.

Architectural invariant: no component has outbound network access to project infrastructure. All outbound connections are either to the AI agent chosen by the user, or to a package manager during updates (optional, off by default).

Deployment scenarios: (A) native installer for desktop, (B) Docker compose for the technically inclined, (C) self-hosting on a VPS/NAS for community deployments. In all three, the same code, the same components, and the same trust model.

---

## 1. System diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                            User environment                              │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                    MyHealth-Europe process                        │   │
│  │                                                                    │   │
│  │  ┌─────────────┐  ┌─────────────────┐  ┌─────────────────────┐  │   │
│  │  │   Adapter   │  │  Local Store    │  │   MCP Server         │  │   │
│  │  │   Layer     │──►│  (encrypted     │◄─│   (stdio + SSE)      │  │   │
│  │  │             │  │   SQLite)       │  │                      │  │   │
│  │  │ • UA        │  │                 │  │  tools:              │  │   │
│  │  │ • EE        │  │  • Resources    │  │   • get_observations │  │   │
│  │  │ • Apple     │  │  • Indices      │  │   • get_medications  │  │   │
│  │  │ • Generic   │  │  • Migrations   │  │   • get_conditions   │  │   │
│  │  │   FHIR R4   │  │                 │  │   • get_summary      │  │   │
│  │  └─────────────┘  └─────────────────┘  │   • search_records   │  │   │
│  │         ▲                  ▲             └──────────┬─────────┘  │   │
│  │         │                  │                        │            │   │
│  │         │ file             │ scoped read            │ token      │   │
│  │         │ brought          │ after validation       │ check      │   │
│  │         │ by user          │                        │            │   │
│  │         │                  │                        ▼            │   │
│  │         │           ┌──────┴────────────┐  ┌─────────────────┐  │   │
│  │         │           │   Audit Log       │  │  Consent        │  │   │
│  │         │           │   (append-only,   │◄─│  Gateway        │  │   │
│  │         │           │    structured)    │  │  (OAuth 2.1)    │  │   │
│  │         │           └───────────────────┘  └────────┬────────┘  │   │
│  │         │                                            │           │   │
│  │  ┌──────┴──────────────────────────────────┐        │           │   │
│  │  │       UI Backend (Rust + axum)           │◄───────┘           │   │
│  │  │   - REST API for the UI                   │   consent prompts │   │
│  │  │   - WebSocket for live notifications      │                   │   │
│  │  └────────────────────┬─────────────────────┘                   │   │
│  │                       │                                          │   │
│  └───────────────────────┼──────────────────────────────────────────┘   │
│                          │ localhost:7777 (UI)                            │
│                          │ stdio (MCP)                                    │
│                          │                                                │
│  ┌───────────────────────▼──────────┐   ┌─────────────────────────────┐  │
│  │   UI Frontend (browser tab,      │   │  AI Agent (Claude Desktop,  │  │
│  │   localhost-only)                 │   │  Ollama, OpenAI Desktop,    │  │
│  │                                   │   │  etc.)                       │  │
│  │   - Import wizard                 │   │                              │  │
│  │   - Records browser               │   │  Calls MCP tools             │  │
│  │   - Consent prompts               │   │  → Consent Gateway           │  │
│  │   - Audit-log viewer              │   │  → receives data (or deny)   │  │
│  │   - Settings                      │   │                              │  │
│  └──────────────────────────────────┘   └──────────┬───────────────────┘  │
│                                                     │                       │
└─────────────────────────────────────────────────────┼───────────────────────┘
                                                       │
                                  ─────────────────────┼─────────────────────►
                                                       │  (optional egress
                                                       │   to cloud AI)
                                                       │
                                              ┌────────▼──────────┐
                                              │ Cloud AI API      │
                                              │ (anthropic.com,   │
                                              │  openai.com,      │
                                              │  mistral.ai-EU)   │
                                              │                   │
                                              │ The user knowingly│
                                              │ chose this trust  │
                                              │ level.            │
                                              └───────────────────┘
```

---

## 2. Components

### 2.1. Adapter Layer

**Purpose:** convert data from external source formats into a canonical internal representation (normalized FHIR R4).

**Structure (Rust crate):**
```
crates/adapters/
├── src/
│   ├── lib.rs              # pub trait Adapter
│   ├── ehealth_ua/
│   │   ├── mod.rs          # NSZU-FHIR → canonical R4
│   │   ├── normalizer.rs   # handles NSZU extensions
│   │   └── validator.rs    # NSZU-specific quirks
│   ├── digilugu_ee/
│   │   ├── mod.rs          # Digilugu R4 → canonical (uses ENA spec)
│   │   ├── cda_to_fhir.rs  # legacy CDA bundles
│   │   └── validator.rs
│   ├── apple_health/
│   │   ├── mod.rs
│   │   ├── xml_parser.rs   # Apple XML export
│   │   ├── fhir_export.rs  # iOS 16+ FHIR export
│   │   └── converter.rs    # XML → FHIR
│   └── generic_fhir_r4/    # for future adapters
│       └── mod.rs
└── Cargo.toml
```

**Contract:**
```rust
#[async_trait]
pub trait Adapter: Send + Sync {
    async fn import_file(&self, path: &Path) -> Result<ImportResult, ImportError>;
    fn source_id(&self) -> &'static str;
    fn supports(&self, file: &Path) -> bool;
}

pub struct ImportResult {
    pub records: Vec<FhirResource>,  // fhirbolt strong-typed
    pub warnings: Vec<ImportWarning>,
    pub stats: ImportStats,
}
```

**Does not do:** does not store, does not validate consent, does not write to the audit log. It simply converts and returns.

### 2.2. Local Store

**Purpose:** encrypted storage of FHIR records with a query API.

**Technology stack (Rust):**
- SQLite via `rusqlite` with the `bundled-sqlcipher` feature (full-DB encryption as baseline, AES-256 at the page level — ADR-009).
- Additionally, application-layer AES-GCM via the `aes-gcm` crate for the most sensitive PHI fields (free-text `Observation.note`, mental health observations, diagnostic narratives). Defense-in-depth: if the SQLCipher key leaks from RAM, these fields remain encrypted with a separate per-record key; in addition, this enables GDPR right-to-erasure by discarding the per-record key (the data becomes unreachable even from backup).
- The `argon2` crate for key derivation from a passphrase (Argon2id, ≥64 MB, ≥3 iterations).
- `secrecy` + `zeroize` for safe storage of keys in memory (mlock where possible, zeroing after use).

**Schema:**
```sql
CREATE TABLE resources (
    id              TEXT PRIMARY KEY,         -- FHIR resource.id
    resource_type   TEXT NOT NULL,            -- 'Observation', 'Condition', ...
    encrypted_blob  BLOB NOT NULL,            -- AES-GCM(plaintext, ke)
    nonce           BLOB NOT NULL,
    source          TEXT NOT NULL,            -- 'UA', 'EE', 'apple', ...
    imported_at     TIMESTAMP NOT NULL,
    -- Indices for queries without decrypting the blob:
    category        TEXT,                     -- 'lab', 'vital', 'social-history', ...
    date_recorded   TIMESTAMP,
    -- Soft-delete:
    deleted_at      TIMESTAMP NULL
);

CREATE INDEX idx_type_category_date ON resources(resource_type, category, date_recorded);

CREATE TABLE audit_log (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp       TIMESTAMP NOT NULL,
    event_type      TEXT NOT NULL,            -- IMPORT, CONSENT_GRANTED, READ, ...
    agent_id        TEXT NULL,
    scope           TEXT NULL,
    metadata_json   TEXT NOT NULL,            -- structured details
    audit_chain_hmac BLOB NOT NULL            -- HMAC including the previous hash for tamper-evidence
);

CREATE TABLE consent_grants (
    audit_id        TEXT PRIMARY KEY,
    agent_id        TEXT NOT NULL,
    scope           TEXT NOT NULL,            -- 'read:observations:lab'
    issued_at       TIMESTAMP NOT NULL,
    expires_at      TIMESTAMP NOT NULL,
    revoked_at      TIMESTAMP NULL,
    token_hash      BLOB NOT NULL              -- hash of the OAuth token
);
```

**Query API (internal, Rust trait):**
```rust
#[async_trait]
pub trait Store: Send + Sync {
    async fn get_resources(
        &self,
        resource_type: ResourceType,
        category: Option<&str>,
        date_range: Option<DateRange>,
        scope_filter: &ScopeFilter,
    ) -> Result<Vec<FhirResource>, StoreError>;

    async fn count_by_category(&self) -> Result<HashMap<String, usize>, StoreError>;
    async fn search_text(&self, query: &str, scope_filter: &ScopeFilter) -> Result<Vec<FhirResource>, StoreError>;
}
```

A note on text search: SQLCipher works transparently for all SQLite queries — a full-text index (FTS5) functions inside the encrypted DB without any change to the queries. For columns with additional application-layer encryption (`Observation.note`, etc.) text search is unavailable — this is a deliberate omission, since deterministic encryption over PHI fields leaks pattern-frequency information (for medical codes and diagnoses this means trivial re-identification — see ADR-009).

**Does not store:** plaintext PHI outside of runtime memory; encryption keys (only derived from the passphrase per session, in `Secret<[u8; 32]>` from the `secrecy` crate).

### 2.3. MCP Server

**Purpose:** expose a tools surface for AI agents via the MCP protocol.

**Implementation:** `rmcp` (Anthropic's official Rust SDK).

**Transports:**
- **stdio** (primary) — for local agents like Claude Desktop, Ollama-based, and ChatGPT Desktop.
- **SSE/HTTP** (optional, off by default) — for remote agents in controlled environments; via an `axum` route with OAuth + TLS mandatory.

**Tools (phase 1, read-only) — example in Rust + `rmcp`:**
```rust
use rmcp::{tool, ServerHandler};
use serde::{Deserialize, Serialize};

#[derive(Deserialize)]
pub struct ObservationFilter {
    pub category: Option<String>,      // 'lab', 'vital', 'imaging'
    pub code: Option<String>,           // LOINC code
    pub date_from: Option<NaiveDate>,
    pub date_to: Option<NaiveDate>,
    #[serde(default = "default_limit")]
    pub limit: usize,
}

impl MyHealthServer {
    #[tool]
    async fn get_observations(&self, filter: ObservationFilter, ctx: ToolContext)
        -> Result<Vec<Observation>, McpError> {
        self.consent.check_scope(&ctx.token, "read:observations", &filter)?;
        self.store.get_observations(filter).await.map_err(Into::into)
    }

    #[tool]
    async fn get_medications(&self, filter: MedicationFilter, ctx: ToolContext)
        -> Result<Vec<MedicationRequest>, McpError> { /* ... */ }

    #[tool]
    async fn get_conditions(&self, filter: ConditionFilter, ctx: ToolContext)
        -> Result<Vec<Condition>, McpError> { /* ... */ }

    #[tool]
    async fn get_allergies(&self, ctx: ToolContext)
        -> Result<Vec<AllergyIntolerance>, McpError> { /* ... */ }

    #[tool]
    async fn get_immunizations(&self, ctx: ToolContext)
        -> Result<Vec<Immunization>, McpError> { /* ... */ }

    #[tool]
    async fn get_encounters(&self, filter: EncounterFilter, ctx: ToolContext)
        -> Result<Vec<Encounter>, McpError> { /* ... */ }

    #[tool]
    async fn get_diagnostic_reports(&self, filter: DiagnosticReportFilter, ctx: ToolContext)
        -> Result<Vec<DiagnosticReport>, McpError> { /* ... */ }

    /// Returns an overview WITHOUT PHI (counts, date ranges, categories) —
    /// for agents that select scope intelligently.
    #[tool]
    async fn get_health_summary(&self, ctx: ToolContext)
        -> Result<HealthSummary, McpError> { /* ... */ }

    #[tool]
    async fn search_records(&self, query: String, types: Option<Vec<String>>, ctx: ToolContext)
        -> Result<Vec<FhirResource>, McpError> { /* ... */ }
}
```

**Every tool call** goes through a consent check BEFORE execution. Without a valid token for the scope it returns a structured error: "consent required, request via gateway".

**Resources** (MCP terminology):
- `health://schema/observation` — JSON Schema for Observation.
- `health://examples/lab-summary` — sample agent prompt + response (for onboarding new agents).

**Prompts** (MCP terminology):
- `summarize_recent_labs` — pre-built prompt.
- `medication_reconciliation` — pre-built.
- `cross_border_visit_prep` — pre-built for the UA-EE flow.

### 2.4. Consent Gateway

**Purpose:** an OAuth 2.1 authorization server that issues scoped, time-bound tokens to agents.

**Endpoints:**
- `POST /oauth/authorize` — start the consent flow (with PKCE).
- `POST /oauth/token` — exchange code for token.
- `POST /oauth/revoke` — revoke a token.
- `GET /oauth/sessions` — list active grants (UI).
- `POST /oauth/sessions/{id}/revoke` — UI revoke.

**Token format:** JWT with claims:
```json
{
  "iss": "myhealth-europe-local",
  "sub": "user-pseudonymous-id",
  "aud": "agent:claude-desktop",
  "scope": "read:observations:lab read:medications:active",
  "exp": 1747000000,
  "iat": 1746996400,
  "jti": "consent-audit-id-abc123"
}
```

**Signed with a local-only key** (HMAC-SHA256 with a secret that lives only in runtime). Verified locally; never leaves.

**Flow:**
1. Agent → MCP tool call → MCP server sees "no token".
2. MCP server → consent gateway: "agent X wants scope Y".
3. Gateway → UI Backend → notification to the browser.
4. The user approves / declines in the UI.
5. Gateway issues a token to the agent through MCP.
6. The token is used in subsequent requests — no re-prompt during its TTL.

**Scope grammar:**
```
scope := operation ":" resource_type [":" category] [":" filter]
operation := "read" | "search"
resource_type := "observations" | "conditions" | "medications" | ...
category := "lab" | "vital" | "imaging" | "social-history" | ...
filter := arbitrary key=value (e.g., date>=2025-01)
```

Example: `read:observations:lab:date>=2025-01`.

### 2.5. Audit Log

**Purpose:** an append-only journal of every touch on the data and every consent event.

**Properties:**
- **Append-only** — a separate SQLite table with triggers that block UPDATE/DELETE on main rows.
- **Tamper-evident** — HMAC chain: each record's HMAC includes the hash of the previous record. If anyone substitutes an old event, the chain breaks.
- **Structured** — JSON metadata, schema-driven.
- **Exportable** — the user can request a CSV export of the entire log (for GDPR Art. 15/30 requests).
- **Stores no PHI** — only metadata ('READ observation 47 records'), not the record data itself.

**Rotation:** TTL is 2 years by default; configurable. On rotation, old events are exported to CSV before deletion (e.g., to a USB stick).

### 2.6. UI Backend and UI Frontend

**Backend (Rust + `axum`):**
- Local-only listener on 127.0.0.1:7777 by default.
- REST API for UI operations (axum routes).
- WebSocket for live consent prompts (via `axum::extract::ws`).
- Simple auth: passphrase challenge at the start of a session (rotating cookie, signed with the instance secret).
- Static assets (the UI bundle) embedded in the binary via `rust-embed` — single binary, no external file deps.

**Frontend (vanilla JS + htmx — ADR-007):**
- Server-driven MPA. `axum` returns HTML fragments, htmx performs partial swaps — minimal JS, zero build step for basic scenarios.
- Escape valve: one or two Alpine.js islands if complex client-side state becomes necessary in lab-value timeline visualizations. We do not rewrite the stack.
- All assets bundled into the Rust binary via `rust-embed` — no external CDN.
- i18n via JSON resource bundles on the server side (UA, EN, EE, DE, PL).
- WCAG 2.1 AA via axe-core in CI.

**Desktop wrapper (Tauri — ADR-008):**
- The Tauri shell wraps the `axum` UI backend in a native desktop window with system tray, auto-updater, and OS notifications.
- Artifacts: `.msi` (Windows), `.dmg` (macOS), `.AppImage` + `.deb` (Linux). All via `tauri-bundler`.
- Server scenarios (B, C below) install the same Rust binary without the Tauri shell — the binary is self-sufficient.

---

## 3. Deployment Topology

### 3.1. Scenario A — Native desktop install (Persona B — Johann)

```
┌──────────────────────────────────────┐
│  Johann's Windows laptop             │
│                                      │
│  C:\Program Files\MyHealth-Europe\   │
│    ├── myhealth.exe                  │
│    ├── ui/ (bundled)                 │
│    └── ...                           │
│                                      │
│  %APPDATA%\MyHealth-Europe\          │
│    ├── store.db (encrypted)          │
│    ├── audit.db                      │
│    └── config.yaml                   │
│                                      │
│  System tray: 🟢 MyHealth-Europe     │
│  Browser tab: localhost:7777         │
└──────────────────────────────────────┘
```

The installer launches the service at system start. Auto-update is opt-in.

### 3.2. Scenario B — Docker compose (Personas A, C — Anna, Olha)

```yaml
# docker-compose.yml
services:
  myhealth-europe:
    image: myhealtheurope/server:1.0
    container_name: myhealth-europe
    restart: unless-stopped
    ports:
      - "127.0.0.1:7777:7777"
    volumes:
      - myhealth-data:/data
    environment:
      - MYHEALTH_DATA_DIR=/data
      - MYHEALTH_BIND=0.0.0.0:7777
    # no internet egress except for explicit AI agent calls
    networks:
      - default

volumes:
  myhealth-data:
```

```bash
docker compose up -d
open http://localhost:7777
```

### 3.3. Scenario C — Self-hosted on a VPS/NAS (community / advanced users)

```
┌────────────────────────────────┐
│  Home NAS (Synology / TrueNAS) │
│                                │
│  ┌───────────────────────────┐ │
│  │ MyHealth-Europe (Docker)  │ │
│  │                           │ │
│  │ Available at:             │ │
│  │ https://health.home.lan/  │ │
│  │ (via Tailscale or         │ │
│  │  reverse proxy + TLS)     │ │
│  └───────────────────────────┘ │
└────────────────────────────────┘
        ▲                ▲
        │                │
  User's laptop    User's phone
  (browser)        (browser)
```

In this scenario a single instance serves one person across multiple devices. Multi-user is out of scope in phase 1.

---

## 4. Architectural Decision Records (ADRs)

ADRs are kept here (inline in this section — single source of truth, without `docs/adr/` fragmentation).

- **ADR-001:** Local-only architecture (no project-side backend). Status: Accepted. Rationale: privacy-by-architecture.
- **ADR-002:** SQLite + per-record encryption vs SQLCipher. Status: Superseded by ADR-009 (2026-05-12). Closed as a hybrid decision.
- **ADR-003:** stdio as the primary MCP transport. Status: Accepted. Rationale: zero-config for local agents.
- **ADR-004:** OAuth 2.1 rather than a custom protocol. Status: Accepted. Rationale: standard, audit-friendly, downstream-compatible.
- **ADR-005:** Append-only audit log with an HMAC chain. Status: Accepted. Rationale: tamper-evidence for the AI Act.
- **ADR-006:** Tech stack: Rust + `rmcp`. Status: Accepted (2026-05-12). Rationale — in `05-tech-stack.md` section 8.
- **ADR-007:** Frontend — vanilla JS + htmx, server-driven MPA. Status: Accepted (2026-05-12). Rationale: aligns with the single-binary deployment thesis (no Node toolchain); minimal JS attack surface for PHI software; transparent build pipeline for audit. Alpine.js as a targeted escape valve for timeline visualizations, if needed. The SvelteKit alternative was rejected: the Node toolchain adds 200+ npm transitive dependencies and breaks the Rust-binary thesis for a benefit that, in our UI scope (CRUD + list + detail + a few charts), is not needed.
- **ADR-008:** Installer — Tauri shell over the axum UI backend. Status: Accepted (2026-05-12). Rationale: a non-technical audience (patients with low technical preparation) — the "open http://localhost:7777" scenario knocks out 70% of non-technical users in the first minute; Tauri provides a native window, system tray, auto-updater, and OS notifications, while itself being a Rust project (preserving the Rust-first ethos); a webview is already present in every modern OS — no new dependency is added; the `.msi`/`.dmg`/`.AppImage` artifacts are a two-click install. WiX + cargo-bundle remains as a fallback in case Tauri starts breaking. Server scenarios (Docker, NAS) launch the same Rust binary without the Tauri shell — the binary is self-sufficient.
- **ADR-009:** Storage encryption — SQLCipher full-DB encryption (baseline) + application-layer AES-GCM column-level for the most sensitive PHI fields (defense-in-depth). Status: Accepted (2026-05-12, supersedes ADR-002). Rationale: SQLCipher is battle-tested (Signal, 1Password), FIPS-validated builds exist, `rusqlite` has first-class support via `bundled-sqlcipher`; the pure-Rust thesis is overrated since we already depend on C through the TLS stack (aws-lc-rs/OpenSSL). Application-layer AES-GCM on `secrecy::Secret` for free-text notes, diagnoses, and mental health observations gives (a) defense-in-depth if the SQLCipher key is compromised in RAM, (b) per-record key rotation for GDPR right-to-erasure (we discard the key — the data becomes unreachable even from backup). Rejected: application-only encryption with deterministic-encrypted searchable fields (indices over deterministic-encrypted PHI leak pattern-frequency, which for medical codes and diagnoses = trivial re-identification). Either full SQLCipher + selective column-level, or zero search over sensitive columns — do not mix.

---

## 5. Operational concerns

### 5.1. Versioning

- SemVer for the server: major.minor.patch.
- MCP protocol version pinned (e.g., MCP v0.6) — declared in capabilities.
- Schema migrations via `refinery` or `sqlx-migrate` (Rust).

### 5.2. Updates

- Auto-update OFF by default.
- Manual: download the new installer / `docker pull` / `cargo install --git` (for advanced users).
- Update channel — signed releases on GitHub (`cosign` signatures, SLSA provenance). The installer verifies the signature before applying.

### 5.3. Logging

- Structured JSON logs.
- No PHI in logs (enforced through a lint rule and review).
- Configurable level (default: INFO).

### 5.4. Metrics

- Per-instance local metrics (Prometheus format on /metrics, off by default, available for self-hosters).
- No project-side phone-home.

### 5.5. Crash reports

- Off by default.
- Opt-in to GlitchTip (self-hosted Sentry) — community-run, not project-run.

---

## 6. Cross-cutting concerns

### 6.1. Internationalization

- UI: i18n via JSON resource files per locale.
- Records: FHIR resources are stored in the source's original language; the UI may show them with on-the-fly machine translation (an optional tool in the agent).

### 6.2. Accessibility

- WCAG 2.1 AA for the UI.
- Keyboard navigation everywhere.
- Screen reader labels for consent prompts (especially critical — the user must understand what they are approving).

### 6.3. Error handling

- Per-component error taxonomy.
- User-facing error messages — in the interface language, without stack traces.
- Technical detail available in the devtools panel via opt-in.

---

## 7. Scalability boundaries (explicit)

Phase 1 plans for:
- 1 user per instance.
- ~10–100K FHIR resources for a typical user.
- ~100 concurrent agent tool calls (theoretical max).
- Storage <1 GB per user.

Beyond these limits — out of scope for phase 2 (cluster deployments, family sharing, etc.).

---

*See: [05-tech-stack.md](05-tech-stack.md) for tech-stack decisions; [08-threat-model.md](08-threat-model.md) for security analysis of the architecture; [03-data-flow.md](03-data-flow.md) for dynamic views.*
