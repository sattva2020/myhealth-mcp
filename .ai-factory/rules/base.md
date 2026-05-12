# Базові правила проекту MyHealth-Europe

> Project conventions для всіх AI-агентів. Вихідного коду ще немає (pre-implementation phase),
> тому правила нижче — це plan-based conventions з docs/, які стануть load-bearing після старту M1.
> Після появи реального Rust-коду цей файл уточнюється через `/aif-evolve`.

## Іменування

| Сутність | Конвенція | Приклад |
|----------|-----------|---------|
| Crate / модуль | `snake_case` | `myhealth_core`, `fhir_adapter_ua` |
| Файли `.rs` | `snake_case.rs` | `consent_gateway.rs`, `audit_log.rs` |
| Структури / enums / traits | `PascalCase` | `ConsentToken`, `FhirResource`, `AuditEvent` |
| Функції / методи / змінні | `snake_case` | `validate_token`, `get_observations` |
| Константи | `SCREAMING_SNAKE_CASE` | `DEFAULT_TOKEN_TTL_SECONDS` |
| MCP tools | `snake_case` через двокрапку для namespace | `get_observations`, `search_records` |
| OAuth scopes | `read:<resource>:<filter>` | `read:observations:lab`, `read:medications:active` |
| FHIR resource types | `PascalCase` (як у FHIR R4 spec) | `Observation`, `MedicationStatement` |
| Документи | `NN-kebab-case.md` (з номером) | `01-business-requirements.md` |
| ADR | `docs/adr/NNNN-kebab-case.md` | `docs/adr/0009-encryption-at-rest.md` |

## Структура коду (планована)

Workspace із multi-crate layout:

```
myhealth-europe/
├── Cargo.toml                   # workspace root
├── crates/
│   ├── myhealth-core/           # SDK / shared types (FHIR models, errors)
│   ├── myhealth-store/          # SQLite + SQLCipher + AES-GCM encryption
│   ├── myhealth-mcp/            # MCP server (rmcp-based, stdio + SSE)
│   ├── myhealth-consent/        # OAuth 2.1 Consent Gateway
│   ├── myhealth-audit/          # Append-only audit log
│   ├── myhealth-ui/             # axum + htmx UI backend
│   ├── myhealth-cli/            # CLI (myhealth import/backup/restore/...)
│   └── adapters/
│       ├── adapter-ua-nszu/     # eHealth UA (NSZU-FHIR)
│       ├── adapter-ee-digilugu/ # Estonia Digilugu (CDA→FHIR)
│       ├── adapter-apple/       # Apple Health (XML→FHIR)
│       └── adapter-generic-r4/  # Generic FHIR R4
├── installers/                  # tauri-bundler configs (.msi/.dmg/.AppImage/.deb)
├── docker/                      # Dockerfile, compose.yml
├── docs/                        # Документація (BRD/PRD/architecture/threat-model/ADRs)
└── tests/                       # Integration + property-based + benchmarks
```

Жорсткі межі залежностей (deny circles):
- `adapters/*` → `myhealth-core` (тільки)
- `myhealth-store` → `myhealth-core`
- `myhealth-mcp` → `myhealth-store`, `myhealth-consent`, `myhealth-audit`, `myhealth-core`
- `myhealth-consent` → `myhealth-audit`, `myhealth-core`
- `myhealth-ui` → усі crates
- `myhealth-cli` → усі crates крім `myhealth-ui`

## Обробка помилок

- **Crate-rivenni error types через `thiserror`** — кожен crate має свій `Error`-enum, без `Box<dyn Error>` у публічному API.
- **`anyhow::Result` тільки у `myhealth-cli`** — бінарі можуть використовувати `anyhow` для контексту, бібліотечні crates — ні.
- **Жодного `.unwrap()` / `.expect()` у production code path.** Дозволено лише у тестах і у `main.rs` для panic-on-startup config errors.
- **PHI ніколи не потрапляє у `Display`/`Debug` для error types.** Помилки містять ідентифікатори (record id, resource type), не вміст.
- **`Result<T, E>`-first.** `panic!`/`unreachable!` лише з explicit safety-коментарем поряд.

## Логування і телеметрія

- **`tracing` для structured logs** з JSON output через `tracing-subscriber`.
- **Log levels:** `error` (потребує уваги), `warn` (нештатна ситуація, але продовжуємо), `info` (state transitions), `debug` (developer), `trace` (verbose).
- **No PHI у logs.** Замість `tracing::info!("imported {bundle:?}")` — `tracing::info!(record_count = bundle.entries.len(), source = %source_name, "import completed")`.
- **No telemetry by default.** `telemetry=disabled` у default config (NFR-S5).
- **Audit-events (grant/deny/revoke/read) — окремий append-only канал**, не звичайний `tracing`-лог.

## Шифрування і робота з секретами

- **`secrecy::SecretString` / `secrecy::SecretVec` для всіх ключів і passphrase.** Ніколи не `String` для секретів.
- **`zeroize` для structs з sensitive data** — `#[derive(ZeroizeOnDrop)]` де можливо.
- **Argon2id KDF** з memory ≥64MB, iterations ≥3, parallelism ≥4 (FR-2.2).
- **AES-256-GCM з random nonce** для application-layer column encryption.
- **SQLCipher через `rusqlite` feature `bundled-sqlcipher`** для full-DB encryption baseline.
- **Жодного hardcoded key / passphrase / token** у коді, тестах або фікстурах. Тестові ключі — generated per-test.
- **CI secret scanning** через Trufflehog/Gitleaks pre-commit і у GitHub Actions.

## Тестування

- **`cargo test` для unit + integration.**
- **`proptest` для property-based** на FHIR-парсерах, OAuth flows, encryption roundtrips.
- **`criterion` для benchmarks** — `cargo bench` (NFR-P1: p99 <200ms).
- **Integration tests:** `tests/` директорія верхнього рівня, із real SQLCipher store (без mocks для шифрування).
- **Coverage targets:** ≥80% lines, ≥70% branches (NFR-M1). Tarpaulin або grcov у CI.
- **Раpsberry Pi 4 smoke test у CI** — `cross`-build для `aarch64-unknown-linux-gnu` + QEMU run.

## Linting і форматування

- **`rustfmt` — обов'язково перед commit** (pre-commit hook + CI check).
- **`clippy` з `-D warnings` на main** (NFR-M2). Дозволено `#[allow(...)]` лише з коментарем-обґрунтуванням.
- **`cargo-audit` у CI** — fail на нові CVE.
- **`cargo-deny` у CI** — policy для ліцензій, sources, advisories, banned crates.

## Документація коду

- **100% public API має doc comments (`///`)** (NFR-M3). Внутрішні `fn` / `struct` — за потреби.
- **`#![deny(missing_docs)]` на crate-level** для бібліотечних crates.
- **Doctests obov'yazkovi для нетривіальних публічних функцій** — приклад використання у docstring.
- **ADR для всіх non-trivial choices** у `docs/adr/NNNN-kebab-case.md`.

## Архітектурні інваріанти (захист на рівні коду)

- **No outbound network з server-process** окрім explicit user-initiated calls. CI має network egress monitoring.
- **PHI ніколи не leaves boundary без consent token validation.** Кожен MCP tool handler починається з `consent.verify(token, scope)?`.
- **Append-only audit log** — `INSERT`-only, без `UPDATE` / `DELETE` на audit table.
- **Resources read-only у phase 1.** Write-back tools — out of scope (FR-3.8).
- **No PHI у backup-файлах без шифрування.** `myhealth backup` створює лише encrypted blob.

## Git / commits

- **Conventional Commits** (`/aif-commit` для генерації повідомлень).
- **Гілки:** `feature/` для нових фіч, `fix/` для багфіксів. Поточне налаштування `git.create_branches: false` → `/aif-plan full` залишається на поточній гілці.
- **Base branch:** `main`.
- **No `--no-verify` / `--no-gpg-sign`** без явного дозволу.
- **Signed releases** через `cosign` (NFR-S4).

## i18n / Мовні правила

- **Документація:** українська (вихідна), з можливим перекладом на EN/EE/DE/PL у v1.0 (FR-5.9).
- **Технічні терміни (Rust, FHIR, OAuth, MCP, SQLite, etc.) — у оригіналі**, не транслітеруються.
- **UI strings:** через `fluent` або `rust-i18n` (визначиться у M6); ніколи не hard-coded у компонентах.
- **Error messages для end-users:** локалізовані; для developers / logs — English.

## Залежності і supply chain

- **Преферуємо crates з audit history** (Signal, Bitwarden, Tokio ecosystem).
- **Нові dependencies — review через ADR** якщо вони у `[dependencies]` основного crate (не dev/build).
- **`cargo-cyclonedx` для SBOM** з кожним release у CycloneDX format.
- **Dependabot** для security updates.
- **SLSA Level 2** як ціль для release pipeline.
