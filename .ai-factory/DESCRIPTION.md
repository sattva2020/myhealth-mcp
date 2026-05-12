# MyHealth-Europe — Опис проекту

> Цей документ — джерело істини для AI-агентів щодо WHAT (продукт) і WHY (наміри).
> HOW (реалізація) — у `ARCHITECTURE.md` та `docs/06-architecture.md`.
> Поточний статус: **pre-implementation, design phase** (вихідний код ще не існує).

## Огляд

**MyHealth-Europe** — open-source Model Context Protocol сервер для health-даних під контролем громадян ЄС. Кожен громадянин запускає програму у себе (на ноутбуці, Raspberry Pi, домашньому NAS або self-hosted VPS), імпортує свої FHIR-записи з національних e-health систем (eHealth UA, Estonia Digilugu, Apple Health, generic FHIR R4), і через MCP-протокол надає будь-якому AI-агенту (Claude Desktop, Ollama, OpenAI Desktop) обмежений за scope і часом доступ до конкретних записів — з аудит-логом і явною згодою на кожен сеанс.

Архітектурна властивість, а не обіцянка у privacy policy: проектна команда не має і не матиме доступу ні до одного байту користувацьких даних. Жодного централізованого сховища. Жодного API на проектному сервері. Жодних аналітичних подій.

## Контекст і позиціонування

- **Грантовий драфт:** NGI Zero Commons Fund #13 (v0.2, дедлайн 2026-06-01, запит €50 000).
- **Umbrella-проект:** MyHealth-Europe = Module №1 (Health) ширшого open-source проекту **CivicAI Bridge** (DIGITAL-2027-AI).
- **Команда:** 4 співзасновники — Грибан Р. (Project Lead), Сураєв О. (Coordination), Мирошников Д. (BD/EU networking), Грибан Т. (Domain Advisor).
- **Імплементація:** старт після підписання MoU з NLnet (очікувано Q3 2026).

## Ключові функціональні блоки

1. **FHIR-імпортери** (M2) — адаптери для eHealth UA (NSZU-FHIR), Estonia Digilugu (CDA→FHIR), Apple Health (XML→FHIR), generic FHIR R4 bundle. Idempotent re-import, партіальне відновлення, summary-репорт.
2. **Local Store** (M3) — SQLite із hybrid encryption-at-rest: SQLCipher full-DB baseline + application-layer AES-GCM column-level для найчутливіших PHI-полів. Argon2id KDF з user passphrase; ключ ніколи не записується на диск; p99 query latency <200ms на 10K-record dataset.
3. **MCP-сервер** (M4) — сумісність з MCP spec v0.6+, транспорти stdio + SSE/HTTP, read-only tools (`get_observations`, `get_conditions`, `get_medications`, `get_allergies`, `get_immunizations`, `get_encounters`, `get_diagnostic_reports`, `search_records`, `get_health_summary`), reference resources/prompts. Write-back операції — out of scope phase 1.
4. **Consent Gateway** (M5) — OAuth 2.1 з PKCE, scope-by-resource-type (`read:observations:lab`, `read:medications:active`, …), time-bound токени (5min/1h/24h/7d/30d max), per-resource-type confirmation для sensitive categories (psych, sexual, genetic), one-click revoke, append-only аудит-лог. Pen-test до M8.
5. **Reference UI client** (M6) — local-only web UI на `localhost:7777`, offline-first (без external CDN), Setup wizard, Records browser, Sessions/consent management, Audit-log viewer, WCAG 2.1 AA, i18n (UA/EN/EE/DE/PL у v1.0).
6. **Reference cross-border navigation agent — HealBot.pro** (M7, AGPL 3.0) — end-to-end демонстрація UA-EE flow: безперервність призначень, виявлення взаємодій, мовний міст, підготовка документа для нового сімейного лікаря у країні destination.
7. **Документація і replication kit** (M9) — 5-min quickstart, deployment guide (Docker/native/RPi/NAS), adapter development guide, API reference (OpenAPI + MCP-tools), synthetic test datasets (CC0), security baseline doc.

## Цільові персони

- **Persona A — Анна, expat у Берліні (34, IT-аналітикиня)** — переїхала з Києва у 2023, має записи у eHealth UA + німецький ePA, хоче cross-border AI-помічника.
- **Persona B — Йоганн, пенсіонер з Мюнхена (71, low-tech)** — проводить зими в Аліканте, потребує single-binary deployment без Docker.
- **Persona C — Ольга, медсестра з Естонії з хронічним станом (42)** — активний користувач Digilugu, працює з local-LLM (Llama на власному ноутбуці).

## Стек технологій (закріплено 2026-05-12)

| Шар | Технологія | Версія | Призначення |
|-----|-----------|--------|-------------|
| **Toolchain** | Rust stable | 1.80+ | Основна мова |
| **Async runtime** | `tokio` | latest | Concurrent agents/HTTP |
| **MCP server** | `rmcp` (офіційний від Anthropic) | latest | MCP protocol implementation |
| **FHIR models** | `fhirbolt` | latest R4 | Strong-typed FHIR R4 |
| **Web framework** | `axum` + `tower` middleware | latest | UI backend, OAuth endpoints |
| **HTTP runtime** | `hyper` (через `axum`/`tokio`) | latest | HTTP layer |
| **Storage** | `rusqlite` з `bundled-sqlcipher` | latest | SQLite + encryption-at-rest |
| **Encryption** | `aes-gcm` + `argon2` + опційно `chacha20poly1305` | latest | AES-256-GCM + Argon2id KDF |
| **Key management** | `secrecy` + `zeroize` | latest | Зануляння ключів у пам'яті |
| **OAuth** | `oauth2` + `jsonwebtoken` (HMAC-SHA256) | latest | Consent gateway |
| **Serialization** | `serde` + `serde_json` | latest | JSON in/out |
| **Logging** | `tracing` + `tracing-subscriber` (JSON output) | latest | Structured logs (без PHI) |
| **Frontend UI** | htmx + server-driven MPA через `axum` | — | Local-only web UI на localhost:7777 |
| **Desktop installer** | `tauri-bundler` (.msi/.dmg/.AppImage/.deb) | latest | End-user desktop installers (ADR-008) |
| **Server packaging** | Docker multi-stage + `.deb`/`.rpm` | — | Server-deployments (B/C сценарії) |
| **Testing** | `cargo test` + `proptest` + `criterion` | latest | Unit + property-based + benchmarks |
| **Lint** | `clippy` (deny warnings on main) | latest | Static analysis |
| **Format** | `rustfmt` | latest | Code formatting |
| **Security scan** | `cargo-audit` + `cargo-deny` | latest | CVE check + dep policy |
| **Cross-compile** | `cargo-zigbuild` + `cross` | latest | Linux/macOS/Windows × x86_64/aarch64 |
| **Releases** | `cosign` signed (SLSA Level 2 ціль) | — | Supply chain integrity |
| **SBOM** | `cargo-cyclonedx` (CycloneDX format) | latest | REUSE + SBOM compliance |
| **CI** | GitHub Actions з matrix builds | — | Build, test, sign |

**Обґрунтування вибору Rust** (повне у `docs/05-tech-stack.md`):
- Single static binary <15MB → core value prop "self-hosted privacy-by-architecture" для Йоганн-persona.
- Memory safety без GC → коротший аудит-звіт для PHI-handling code.
- Resource footprint → працює на Raspberry Pi 4 (2GB) з head room.
- Phase 2 rewrite tax відсутній.
- Alignment з privacy-focused community (Signal, Bitwarden core, AGE).

Ціна вибору: ~2-3 додаткових тижні inception, вужча FHIR-екосистема (mitigated через стабільність FHIR R4), менший пул контриб'юторів у першому році.

## Архітектура

Детальні архітектурні принципи (структура crates, dependency rules, code examples, anti-patterns) — у [`.ai-factory/ARCHITECTURE.md`](ARCHITECTURE.md).

**Pattern:** Modular Monolith + Hexagonal (Ports & Adapters) — Cargo workspace з multi-crate layout, traits-ports у `myhealth-core`, impl-адаптери у профільних crates і `crates/adapters/*`, composition root у `myhealth-cli/src/main.rs`.

## Архітектурні інваріанти

1. **No phone-home.** Жоден компонент не має outbound network доступу до проектних інфраструктур.
2. **Privacy-by-architecture, не privacy-by-policy.** Архітектурна неможливість збирати дані, а не обіцянка не збирати.
3. **Untrusted-client model.** Припускаємо, що AI-агент може бути зловмисний; кожен запит проходить через Consent Gateway.
4. **Local-first.** UI на `localhost:7777`, MCP через stdio або SSE з consent від користувача.
5. **No PHI у logs.** Structured JSON logs (`tracing`); PHI ніколи не серіалізуються у журнал.
6. **Append-only audit log.** Кожен grant/deny/revoke/read — окремий event, неможливо modify-in-place.

## Нефункціональні вимоги (key targets)

- **Performance:** p99 query latency <200ms на 10K records; import 1000 records <30s; idle RSS <100MB; disk без даних <100MB; cold start <3s; Raspberry Pi 4 (2GB) smoke test у CI.
- **Security:** OWASP ASVS L2 baseline; SBOM з кожним release; signed releases (cosign); dependabot; secret scanning (Trufflehog/Gitleaks); зовнішній пен-тест consent flow перед M8.
- **Reliability:** atomic write (crash-safe); backup integrity (restore-test у CI); реверсивні schema migrations.
- **Usability:** WCAG 2.1 AA (axe-core = 0 errors); onboarding <15 хв.
- **Operability:** single-container deployment; native binary Linux/macOS/Windows × x86_64/ARM64; structured JSON logs; `/healthz` без auth; graceful shutdown SIGTERM.
- **Maintainability:** test coverage ≥80% lines / ≥70% branches; lint clean (0 warnings on main); 100% public API doc comments; ADRs у `docs/adr/`.

## Ліцензійна стратегія

| Компонент | Ліцензія | Обґрунтування |
|-----------|----------|---------------|
| MCP-сервер ядро, FHIR-адаптери, Consent Gateway, Reference UI | Apache 2.0 | Максимальна downstream-adoption, patent grant |
| Reference cross-border agent (HealBot.pro) | AGPL 3.0 | Force-multiplier для contributor reciprocity у agent-space |
| Документація, replication kit | CC BY-SA 4.0 | Community knowledge sharing |
| Synthetic test datasets | CC0 | Zero-friction для тестування і derivative works |

Деталі: `docs/07-licensing-strategy.md`.

## Залежності між milestone-ами

```
M1 (repo + CI)
   │
   ▼
M2 (FHIR-імпортери) ──► M3 (local store)
                            │
                            ▼
                       M4 (MCP-сервер) ──► M5 (consent gateway)
                                                │
                                                ▼
                                           M6 (UI client)
                                                │
                                                ▼
                                           M7 (reference agent)
                                                │
                                                ▼
                                      M8 (security audit + pen-test)
                                                │
                                                ▼
                                           M9 (v1.0 release)
```

## Що проект НЕ робить

- ❌ Не збирає дані. Жодного централізованого сховища.
- ❌ Не вимагає cloud-акаунту. Усе працює offline-first.
- ❌ Не залежить від конкретного LLM-провайдера. Будь-який MCP-сумісний клієнт.
- ❌ Не лікує і не дає медичних рекомендацій. Це data-layer, не клінічний продукт.
- ❌ Write-back операцій у phase 1 (FHIR-resources read-only).

## Подальші документи

- `docs/01-business-requirements.md` — BRD: проблема, аудиторія, цілі, KPI, скоуп, обмеження.
- `docs/02-prd.md` — функціональні і нефункціональні вимоги, фічі по M1-M9.
- `docs/03-data-flow.md` — звідки беруться дані, як рухаються, що ніколи не виходить назовні.
- `docs/04-user-flow.md` — user journeys (інсталяція, імпорт, згода, повсякденне використання).
- `docs/05-tech-stack.md` — повне обґрунтування вибору Rust + `rmcp`.
- `docs/06-architecture.md` — компоненти, границі довіри, deployment topology.
- `docs/07-licensing-strategy.md` — Apache 2.0 / AGPL 3.0 split.
- `docs/08-threat-model.md` — STRIDE-аналіз, припущення, контрзаходи.
