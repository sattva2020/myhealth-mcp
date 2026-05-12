# 06 — Architecture

**Документ:** MyHealth-Europe — системна архітектура, компоненти, deployment topology
**Версія:** 0.1
**Дата:** 12 травня 2026
**Власник:** Руслан Грибан

---

## TL;DR (для комісії)

Система складається з шести компонентів, які працюють в одному процесі (або одному Docker-контейнері) на пристрої користувача: (1) Adapter Layer для імпорту FHIR з джерел, (2) Local Store для зашифрованого зберігання, (3) MCP Server як інтерфейс до AI-агентів, (4) Consent Gateway як OAuth-сторож, (5) Audit Log як неперервний журнал, (6) UI Backend і UI Frontend як user-facing шар.

Архітектурний інваріант: жоден компонент не має outbound network доступу до проектних інфраструктур. Усі outbound connections — або до AI-агента, обраного користувачем, або до пакетного менеджера при оновленні (опційно, off by default).

Deployment-сценарії: (A) native installer для desktop, (B) Docker compose для технічно підкованих, (C) self-hosted на VPS/NAS для community-deployments. У всіх трьох — той самий код, ті самі компоненти, та сама trust model.

---

## 1. Системна діаграма

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       Користувацьке окружения                            │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                    MyHealth-Europe процес                          │   │
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
│  │         │ файл             │ scoped read            │ token      │   │
│  │         │ принесений       │ після validation       │ check      │   │
│  │         │ користувачем     │                        │            │   │
│  │         │                  │                        ▼            │   │
│  │         │           ┌──────┴────────────┐  ┌─────────────────┐  │   │
│  │         │           │   Audit Log       │  │  Consent        │  │   │
│  │         │           │   (append-only,   │◄─│  Gateway        │  │   │
│  │         │           │    structured)    │  │  (OAuth 2.1)    │  │   │
│  │         │           └───────────────────┘  └────────┬────────┘  │   │
│  │         │                                            │           │   │
│  │  ┌──────┴──────────────────────────────────┐        │           │   │
│  │  │       UI Backend (Rust + axum)           │◄───────┘           │   │
│  │  │   - REST API для UI                       │   consent prompts │   │
│  │  │   - WebSocket для live notifications      │                   │   │
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
│  │   - Records browser               │   │  Викликає MCP tools          │  │
│  │   - Consent prompts               │   │  → Consent Gateway           │  │
│  │   - Audit-log viewer              │   │  → отримує дані (або deny)   │  │
│  │   - Settings                      │   │                              │  │
│  └──────────────────────────────────┘   └──────────┬───────────────────┘  │
│                                                     │                       │
└─────────────────────────────────────────────────────┼───────────────────────┘
                                                       │
                                  ─────────────────────┼─────────────────────►
                                                       │  (опційний egress
                                                       │   до cloud AI)
                                                       │
                                              ┌────────▼──────────┐
                                              │ Cloud AI API      │
                                              │ (anthropic.com,   │
                                              │  openai.com,      │
                                              │  mistral.ai-EU)   │
                                              │                   │
                                              │ Користувач свідомо│
                                              │ обрав цей trust   │
                                              │ level.            │
                                              └───────────────────┘
```

---

## 2. Компоненти

### 2.1. Adapter Layer

**Призначення:** конвертувати дані з форматів зовнішніх джерел у канонічну внутрішню репрезентацію (FHIR R4 нормалізована).

**Структура (Rust crate):**
```
crates/adapters/
├── src/
│   ├── lib.rs              # pub trait Adapter
│   ├── ehealth_ua/
│   │   ├── mod.rs          # NSZU-FHIR → канонічний R4
│   │   ├── normalizer.rs   # обробка NSZU extensions
│   │   └── validator.rs    # NSZU-specific quirks
│   ├── digilugu_ee/
│   │   ├── mod.rs          # Digilugu R4 → канонічний (uses ENA spec)
│   │   ├── cda_to_fhir.rs  # legacy CDA bundles
│   │   └── validator.rs
│   ├── apple_health/
│   │   ├── mod.rs
│   │   ├── xml_parser.rs   # Apple XML export
│   │   ├── fhir_export.rs  # iOS 16+ FHIR export
│   │   └── converter.rs    # XML → FHIR
│   └── generic_fhir_r4/    # для майбутніх адаптерів
│       └── mod.rs
└── Cargo.toml
```

**Контракт:**
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

**Не робить:** не зберігає, не валідує consent, не пише в аудит-лог. Просто конвертує і повертає.

### 2.2. Local Store

**Призначення:** зашифроване зберігання FHIR-records з query API.

**Технологічний стек (Rust):**
- SQLite через `rusqlite` з `bundled-sqlcipher` feature (full-DB encryption як baseline, AES-256 на сторінковому рівні — ADR-009).
- Додатково — application-layer AES-GCM через `aes-gcm` crate для найчутливіших PHI-полів (free-text `Observation.note`, mental health observations, diagnostic narratives). Defense-in-depth: якщо SQLCipher key витече з RAM, ці поля залишаються зашифрованими окремим per-record ключем; крім того, дозволяє GDPR right-to-erasure через викидання per-record key (дані стають недосяжними навіть у backup).
- `argon2` crate для derivation ключа з passphrase (Argon2id, ≥64MB, ≥3 iterations).
- `secrecy` + `zeroize` для безпечного зберігання ключів у пам'яті (mlock де можливо, zeroing після використання).

**Схема:**
```sql
CREATE TABLE resources (
    id              TEXT PRIMARY KEY,         -- FHIR resource.id
    resource_type   TEXT NOT NULL,            -- 'Observation', 'Condition', ...
    encrypted_blob  BLOB NOT NULL,            -- AES-GCM(plaintext, ke)
    nonce           BLOB NOT NULL,
    source          TEXT NOT NULL,            -- 'UA', 'EE', 'apple', ...
    imported_at     TIMESTAMP NOT NULL,
    -- Індекси для query без розшифровки blob:
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
    audit_chain_hmac BLOB NOT NULL            -- HMAC включаючи попередній hash для tamper-evidence
);

CREATE TABLE consent_grants (
    audit_id        TEXT PRIMARY KEY,
    agent_id        TEXT NOT NULL,
    scope           TEXT NOT NULL,            -- 'read:observations:lab'
    issued_at       TIMESTAMP NOT NULL,
    expires_at      TIMESTAMP NOT NULL,
    revoked_at      TIMESTAMP NULL,
    token_hash      BLOB NOT NULL              -- хеш OAuth token
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

Зауваження по text search: SQLCipher працює прозоро для всіх SQLite-запитів — full-text index (FTS5) функціонує всередині зашифрованої БД без змін до запитів. Для колонок з додатковим application-layer шифруванням (`Observation.note` тощо) text search недоступний — це свідома відмова, оскільки deterministic encryption по PHI-полях течe pattern-frequency інформацію (для медичних кодів і діагнозів означає тривіальну re-identification — див. ADR-009).

**Не зберігає:** plaintext PHI поза runtime memory; encryption key (тільки derived from passphrase per-session, у `Secret<[u8; 32]>` з `secrecy` crate).

### 2.3. MCP Server

**Призначення:** виставити tools-поверхню для AI-агентів через MCP протокол.

**Реалізація:** `rmcp` (Anthropic's official Rust SDK).

**Транспорти:**
- **stdio** (основний) — для local agents типу Claude Desktop, Ollama-based, ChatGPT Desktop.
- **SSE/HTTP** (опційний, off by default) — для remote agents у controlled environments; через `axum` route з OAuth + TLS обов'язково.

**Tools (фаза 1, read-only) — приклад на Rust + `rmcp`:**
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

    /// Повертає overview БЕЗ PHI (counts, date ranges, categories) —
    /// для агентів, що обирають scope інтелігентно.
    #[tool]
    async fn get_health_summary(&self, ctx: ToolContext)
        -> Result<HealthSummary, McpError> { /* ... */ }

    #[tool]
    async fn search_records(&self, query: String, types: Option<Vec<String>>, ctx: ToolContext)
        -> Result<Vec<FhirResource>, McpError> { /* ... */ }
}
```

**Кожен tool-виклик** проходить consent check ПЕРЕД виконанням. Без валідного token для scope — повертає structured error «consent required, request via gateway».

**Resources** (MCP terminology):
- `health://schema/observation` — JSON Schema для Observation.
- `health://examples/lab-summary` — sample agent prompt + response (для onboarding нових агентів).

**Prompts** (MCP terminology):
- `summarize_recent_labs` — pre-built prompt.
- `medication_reconciliation` — pre-built.
- `cross_border_visit_prep` — pre-built для UA-EE флоу.

### 2.4. Consent Gateway

**Призначення:** OAuth 2.1 authorization server, що видає scoped, time-bound tokens агентам.

**Endpoints:**
- `POST /oauth/authorize` — start consent flow (з PKCE).
- `POST /oauth/token` — exchange code for token.
- `POST /oauth/revoke` — revoke token.
- `GET /oauth/sessions` — list active grants (UI).
- `POST /oauth/sessions/{id}/revoke` — UI revoke.

**Token formate:** JWT з claims:
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

**Подписан local-only ключем** (HMAC-SHA256 з секретом, який живе тільки у runtime). Verify локально, не виходить.

**Flow:**
1. Агент → MCP tool call → MCP server бачить «немає token».
2. MCP server → consent gateway: «agent X хоче scope Y».
3. Gateway → UI Backend → notification до browser.
4. Користувач затверджує / відхиляє у UI.
5. Gateway видає token agent-у через MCP.
6. Token у наступних запитах — без re-prompt протягом TTL.

**Scope grammar:**
```
scope := operation ":" resource_type [":" category] [":" filter]
operation := "read" | "search"
resource_type := "observations" | "conditions" | "medications" | ...
category := "lab" | "vital" | "imaging" | "social-history" | ...
filter := arbitrary key=value (e.g., date>=2025-01)
```

Приклад: `read:observations:lab:date>=2025-01`.

### 2.5. Audit Log

**Призначення:** append-only журнал усіх дотиків до даних і consent-подій.

**Властивості:**
- **Append-only** — інша таблиця SQLite з тригерами, що блокують UPDATE/DELETE на main rows.
- **Tamper-evident** — HMAC-chain: кожен запис HMAC включає hash попереднього запису. Якщо хтось підмінить старий event — chain breaks.
- **Структурований** — JSON metadata, грідовний schema.
- **Експортовний** — користувач може запитати CSV-експорт усього лога (для GDPR Art. 15/30 запитів).
- **Не зберігає PHI** — тільки метадані ('READ observation 47 records'), не самі дані records.

**Rotation:** TTL за замовчуванням 2 роки; конфігурований. При rotation — старі events експортуються у CSV перед видаленням (можна на USB).

### 2.6. UI Backend і UI Frontend

**Backend (Rust + `axum`):**
- Local-only listener на 127.0.0.1:7777 за замовчуванням.
- REST API для UI операцій (axum routes).
- WebSocket для live consent prompts (через `axum::extract::ws`).
- Простий auth: passphrase challenge на старті sesia (rotating cookie, signed з instance secret).
- Static assets (UI bundle) embedded у binary через `rust-embed` — single binary, no external file deps.

**Frontend (vanilla JS + htmx — ADR-007):**
- Server-driven MPA. `axum` віддає HTML-фрагменти, htmx робить partial swap'и — мінімум JS, нуль build-step для basic-сценаріїв.
- Escape valve: один-два Alpine.js islands якщо complex client-side state знадобиться у timeline-візуалізаціях лабораторних показників. Стек не переписуємо.
- Всі assets bundled у Rust binary через `rust-embed` — немає external CDN.
- i18n через JSON resource bundles на server-side (UA, EN, EE, DE, PL).
- WCAG 2.1 AA через axe-core у CI.

**Desktop wrapper (Tauri — ADR-008):**
- Tauri-shell обертає `axum` UI backend у native desktop window з system tray, auto-updater, OS notifications.
- Артефакти: `.msi` (Windows), `.dmg` (macOS), `.AppImage` + `.deb` (Linux). Все через `tauri-bundler`.
- Server-сценарії (B, C нижче) ставлять той самий Rust-binary без Tauri-shell — binary self-sufficient.

---

## 3. Deployment Topology

### 3.1. Сценарій A — Native desktop install (Persona B — Йоганн)

```
┌──────────────────────────────────────┐
│  Йоганн's Windows laptop             │
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

Installer запускає сервіс при старті системи. Auto-update — opt-in.

### 3.2. Сценарій B — Docker compose (Personas A, C — Анна, Ольга)

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

### 3.3. Сценарій C — Self-hosted на VPS/NAS (community / advanced users)

```
┌────────────────────────────────┐
│  Home NAS (Synology / TrueNAS) │
│                                │
│  ┌───────────────────────────┐ │
│  │ MyHealth-Europe (Docker)  │ │
│  │                           │ │
│  │ Available at:             │ │
│  │ https://health.home.lan/  │ │
│  │ (через Tailscale або      │ │
│  │  reverse proxy + TLS)     │ │
│  └───────────────────────────┘ │
└────────────────────────────────┘
        ▲                ▲
        │                │
  User's laptop    User's phone
  (browser)        (browser)
```

В цьому сценарії одна instance обслуговує одну особу з кількох пристроїв. Multi-user — out of scope у фазі 1.

---

## 4. Architectural Decision Records (ADRs)

ADR-и зберігаються тут (inline у цьому розділі — single source of truth, без `docs/adr/` фрагментації).

- **ADR-001:** Local-only architecture (немає бекенду проекту). Status: Accepted. Rationale: privacy-by-architecture.
- **ADR-002:** SQLite + per-record encryption vs SQLCipher. Status: Superseded by ADR-009 (2026-05-12). Закрито як hybrid-decision.
- **ADR-003:** stdio як основний MCP транспорт. Status: Accepted. Rationale: zero-config для local agents.
- **ADR-004:** OAuth 2.1 а не custom protocol. Status: Accepted. Rationale: стандарт, аудит-friendly, downstream-сумісний.
- **ADR-005:** Append-only audit log з HMAC chain. Status: Accepted. Rationale: tamper-evidence для AI Act.
- **ADR-006:** Tech stack: Rust + `rmcp`. Status: Accepted (2026-05-12). Rationale — у `05-tech-stack.md` розділ 8.
- **ADR-007:** Frontend — vanilla JS + htmx, server-driven MPA. Status: Accepted (2026-05-12). Rationale: aligns зі single-binary deployment thesis (без Node toolchain); мінімум JS attack surface для PHI-софту; transparent build pipeline для аудиту. Alpine.js як точковий escape valve для timeline-візуалізацій, якщо знадобиться. Альтернатива SvelteKit відкинута: Node toolchain додає 200+ npm транзитивних залежностей і ламає Rust-binary thesis для зиску, який у нашому UI-скоупі (CRUD + список + детальна + кілька chart-ів) не потрібен.
- **ADR-008:** Installer — Tauri-shell поверх axum UI backend. Status: Accepted (2026-05-12). Rationale: непрофільна аудиторія (пацієнти з низькою технічною підготовкою) — сценарій "відкрийте http://localhost:7777" вирубає 70% non-technical users у першу хвилину; Tauri дає native window, system tray, авто-апдейтер, OS notifications, при цьому сам є Rust-проєктом (зберігає Rust-first ethos); webview і так присутній у кожній сучасній OS — нова залежність не додається; артефакти `.msi`/`.dmg`/`.AppImage` — двокліковий install. WiX + cargo-bundle лишається як fallback на випадок, якщо Tauri почне ламатись. Server-сценарії (Docker, NAS) той самий Rust-binary запускають без Tauri-shell — binary self-sufficient.
- **ADR-009:** Storage encryption — SQLCipher full-DB encryption (baseline) + application-layer AES-GCM column-level для найчутливіших PHI-полів (defense-in-depth). Status: Accepted (2026-05-12, supersedes ADR-002). Rationale: SQLCipher — battle-tested (Signal, 1Password), FIPS-validated builds існують, `rusqlite` має first-class підтримку через `bundled-sqlcipher`; pure-Rust теза переоцінена, оскільки ми вже залежимо від C через TLS-стек (aws-lc-rs/OpenSSL). Application-layer AES-GCM на `secrecy::Secret` для free-text notes, diagnoses, mental health observations дає (а) defense-in-depth якщо SQLCipher key компрометовано в RAM, (б) per-record key rotation для GDPR right-to-erasure (викидаємо ключ — дані недосяжні навіть у backup). Відкинуто: application-only encryption з deterministic-encrypted searchable полями (індекси по deterministic-encrypted PHI течуть pattern-frequency, для медичних кодів і діагнозів = тривіальна re-identification). Або повне SQLCipher + selective column-level, або zero search по чутливих колонках — не змішувати.

---

## 5. Operational concerns

### 5.1. Versioning

- SemVer для server: major.minor.patch.
- MCP protocol version pin (e.g., MCP v0.6) — declared у capabilities.
- Schema migrations через `refinery` або `sqlx-migrate` (Rust).

### 5.2. Updates

- Auto-update OFF by default.
- Manual: завантажити новий installer / `docker pull` / `cargo install --git` (для advanced users).
- Update channel — signed releases на GitHub (`cosign` signatures, SLSA provenance). Installer перевіряє підпис перед apply.

### 5.3. Logging

- Structured JSON logs.
- No PHI у logs (enforced through lint rule і review).
- Configurable level (default: INFO).

### 5.4. Metrics

- Per-instance local metrics (Prometheus format на /metrics, off by default, available для self-hosters).
- No proja phone-home.

### 5.5. Crash reports

- Off by default.
- Opt-in to GlitchTip (self-hosted Sentry) — communality-run, не проектний.

---

## 6. Cross-cutting concerns

### 6.1. Internationalization

- UI: i18n через JSON resource files per locale.
- Records: FHIR-resources зберігаються у мові-оригіналі джерела; UI може показувати з machine-translation на льоту (опційний tool у агента).

### 6.2. Accessibility

- WCAG 2.1 AA для UI.
- Keyboard navigation everywhere.
- Screen reader labels для consent prompts (особливо критично — користувач повинен розуміти, що схвалює).

### 6.3. Error handling

- Per-component error taxonomy.
- User-facing error messages — на мові інтерфейсу, без stack traces.
- Технічний detail доступний у devtools panel за opt-in.

---

## 7. Scalability boundaries (явні)

Фаза 1 розраховує:
- 1 користувач per instance.
- ~10-100K FHIR resources на typical user.
- ~100 concurrent agent tool calls (theoretical max).
- Storage <1GB per user.

Поза цими межами — за scope фази 2 (cluster deployments, family-sharing, etc.).

---

*Дивись: [05-tech-stack.md](05-tech-stack.md) для tech-stack рішень; [08-threat-model.md](08-threat-model.md) для security аналізу архітектури; [03-data-flow.md](03-data-flow.md) для динамічних views.*
