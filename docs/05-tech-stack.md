# 05 — Tech Stack

**Документ:** MyHealth-Europe — вибір технологічного стеку
**Версія:** 0.1
**Дата:** 12 травня 2026
**Власник:** Руслан Грибан
**Статус:** **закріплено** — Rust з самого початку (рішення апліканта, 2026-05-12).

---

## TL;DR (для команди і комісії)

Розглянуто чотири реалістичних кандидати: **Python+FastMCP**, **TypeScript** (Node.js), **Go**, **Rust**. Кожен оцінено по семи критеріях: зрілість MCP SDK, екосистема FHIR, deployment простота, performance, security baseline, learning/maintenance curve для апліканта, fit для self-hosted health-софту.

**Прийняте рішення: Rust + `rmcp` як основний стек з M1.** Хоча у weighted score Python формально вищий (4.27 проти 3.93), якісний аналіз — deployment-simplicity для Йоганн-persona, memory safety без GC для PHI-handling, single static binary <15MB як reference deployment для self-hosted health-софту — переважив. Project-thesis ("кожен громадянин ЄС повинен мати інструмент, який запускається без зайвих залежностей") вимагає Rust-class deployment story з самого початку, не як phase 2 rewrite.

Ціна вибору: ~2-3 додаткових тижні inception (Rust scaffolding, ramp-up на `rmcp` і `fhirbolt`), вужча FHIR-екосистема (mitigated через те, що FHIR R4 schema стабільна — раз написаний strong-typed parser працює), менший пул потенційних контриб'юторів у першому році. Виграші — у розділі 6.3 нижче.

---

## 1. Контекст вибору

Кандидата технологічного стеку треба обрати так, щоб він одночасно задовольнив п'ять обмежень:

1. **Команда розробки — 1 engineer (Грибан Р.) на 6 PM** з можливістю part-time контриб'ютера на FHIR-інжестер (2 PM). Стек повинен бути продуктивним для цього розміру команди.
2. **Open-source community і downstream-adoption.** Стек повинен бути доступним для контриб'юторів і не блокувати adoption через екзотичність.
3. **Self-hosted deployment** на різних таргетах: Linux x86/ARM (включно з Raspberry Pi 4), macOS, Windows, Docker.
4. **Health-domain екосистема:** FHIR-парсери і валідатори, healthcare standard support.
5. **Безпекова baseline:** memory safety, supply chain hygiene, audit-friendly.

Інтервал прийняття: до старту M1 (передбачаваний Q3 2026). Документ цей з'являється pre-grant, рішення — на team review після грантового award.

---

## 2. Критерії оцінки

| # | Критерій | Вага | Чому це важливо |
|---|----------|------|-----------------|
| C1 | Зрілість MCP SDK | 0.20 | MCP — серце проекту. Зрілий SDK = менше bugfixing рідного коду. |
| C2 | Екосистема FHIR / health | 0.18 | Зекономить тижні на парсерах, валідаторах, R4 schema. |
| C3 | Deployment простота для end-user | 0.15 | Йоганн-persona — обмежуючий фактор. Single binary > Docker > runtime. |
| C4 | Performance і resource footprint | 0.12 | Raspberry Pi 4 — таргет. p99 <200ms — вимога. |
| C5 | Security baseline (memory safety, supply chain) | 0.15 | Health-софт з PHI = high stakes. |
| C6 | Productivity для апліканта (learning curve, maintenance) | 0.12 | 1 engineer × 6 PM не дає буфера на масштабний learning. |
| C7 | Open-source adoption / contributor accessibility | 0.08 | Apache 2.0 + adoption — частина value. |

Шкала: 1 (поганий) — 5 (відмінний).

---

## 3. Кандидат 1: Python + FastMCP

### 3.1. Що це

- **Python 3.12+**.
- **FastMCP** ([github.com/jlowin/fastmcp](https://github.com/jlowin/fastmcp) — community-driven, або офіційний `mcp` Python SDK від Anthropic).
- FHIR-екосистема: `fhir.resources` (Pydantic-based FHIR R4/R5 models), `fhirpathpy`, `hl7apy` для legacy HL7v2.
- Web framework для UI backend: FastAPI.
- Storage: SQLAlchemy + SQLite (з `pysqlcipher3` для encryption-at-rest) або prosto SQLite + per-record encryption через `cryptography`.
- OAuth: `authlib`.
- Packaging: Docker (основна форма), PyInstaller або `briefcase` для native binary.

### 3.2. Оцінка по критеріях

| Критерій | Бал | Пояснення |
|----------|-----|-----------|
| C1 — MCP SDK | 5/5 | Найзріліший SDK; офіційний від Anthropic; широке prikladne використання |
| C2 — FHIR екосистема | 5/5 | Найбагатша: `fhir.resources` має повне R4 + R5 покриття, `fhirpathpy`, інтеграції з SMART on FHIR |
| C3 — Deployment | 3/5 | Docker — норм. Native binary через PyInstaller — можливо, але heavier (~50-100MB). Йоганн зможе через installer wrapper |
| C4 — Performance | 3/5 | Async Python з FastAPI достатньо для типового кейсу. CPU-heavy парсинг великих bundle-ів — повільніше за Rust/Go в 5-10×. Raspberry Pi 4 — OK для скромних обсягів |
| C5 — Security | 3.5/5 | Memory safety є (GC), але dependency tree великий → supply chain risk вище. CVE-history typical for Python ecosystems. SBOM + signed releases mitigate |
| C6 — Productivity для апліканта | 5/5 | Аплікант має 3+ роки MCP-серверів. Python — основний робочий стек. Найменше learning curve |
| C7 — Adoption / contributors | 5/5 | Python — №1 у health-data ecosystem. Найбільший пул контриб'юторів |

**Weighted score: 0.20×5 + 0.18×5 + 0.15×3 + 0.12×3 + 0.15×3.5 + 0.12×5 + 0.08×5 = 4.27/5**

### 3.3. Плюси

- Максимально швидкий старт.
- Найбільша екосистема FHIR (це не дрібниця — `fhir.resources` сам по собі економить тижні).
- Аплікант продуктивний з першого дня.
- Найбільший потенційний пул контриб'юторів.
- Reference імплементації MCP сервера у Python широко доступні.

### 3.4. Мінуси

- Deployment не такий чистий, як native binary.
- Supply chain — більше залежностей → більше attack surface.
- Performance — добре, але не excellent на CPU-bound FHIR parsing for великих bundle-ів.
- Раніше за інших застаріє з точки зору performance, якщо проект масштабуватися на cluster-deploy (фаза 3+).

---

## 4. Кандидат 2: TypeScript (Node.js)

### 4.1. Що це

- **Node.js 22+ LTS**, **TypeScript 5.x**.
- MCP: `@modelcontextprotocol/sdk` (офіційний від Anthropic для TS).
- FHIR-екосистема: `@types/fhir`, `fhir-kit-client`, `medplum-fhir-types`. Слабша за Python.
- Web framework: Fastify або Hono.
- Storage: better-sqlite3 + cipher через application-layer encryption.
- OAuth: `oidc-provider`.
- Packaging: Docker, або `pkg` / `nexe` для bundled executable.

### 4.2. Оцінка

| Критерій | Бал | Пояснення |
|----------|-----|-----------|
| C1 — MCP SDK | 5/5 | Офіційний TS SDK; equal to Python у функціональності |
| C2 — FHIR екосистема | 3/5 | Має базові types, але парсери і валідатори менш зрілі. Medplum-екосистема росте, але вона client-focused |
| C3 — Deployment | 3.5/5 | Docker — норм. `pkg` дає single binary, але із Node-runtime embedded (60-80MB) |
| C4 — Performance | 3.5/5 | V8 — швидко для I/O, але CPU-bound FHIR парсинг ~рівне Python |
| C5 — Security | 3/5 | Memory safety є (V8). npm supply chain — гірше за Python (більше малих залежностей, історія incident-ів типу `event-stream`) |
| C6 — Productivity апліканта | 3.5/5 | Аплікант комфортний з TS, але не основний стек |
| C7 — Adoption | 4/5 | Великий community, але health-domain менше |

**Weighted score: 0.20×5 + 0.18×3 + 0.15×3.5 + 0.12×3.5 + 0.15×3 + 0.12×3.5 + 0.08×4 = 3.61/5**

### 4.3. Плюси

- Якщо хочемо UI client і server у одному репо/мові — TS дозволяє code-sharing types.
- Async by default, добре для concurrent agent requests.
- Великий пул контриб'юторів.

### 4.4. Мінуси

- Слабша FHIR-екосистема.
- npm supply chain risk.
- Аплікант менш продуктивний, ніж у Python.

---

## 5. Кандидат 3: Go

### 5.1. Що це

- **Go 1.23+**.
- MCP: `mcp-go` (community-driven, є кілька реалізацій; offizielnyy Anthropic Go SDK ще emerging станом на 2026).
- FHIR-екосистема: `github.com/SamuelBoehm/fhir` (R4 models), `github.com/google/fhir` (Google, але великий і складний), Bonfhir (R5).
- Web framework: standard library + chi router.
- Storage: SQLite через `mattn/go-sqlite3` + application-layer encryption.
- OAuth: `golang.org/x/oauth2`.
- Packaging: native cross-compile до single static binary, ~10-20MB.

### 5.2. Оцінка

| Критерій | Бал | Пояснення |
|----------|-----|-----------|
| C1 — MCP SDK | 3/5 | Менш зрілий, кілька конкуруючих implementations |
| C2 — FHIR екосистема | 3/5 | Google FHIR — мажорний, але heavy. SamuelBoehm — простіший. Менше choice |
| C3 — Deployment | 5/5 | Native single binary, cross-compile тривіальний. Йоганн отримує `myhealth.exe` — і все працює |
| C4 — Performance | 4.5/5 | Швидко, низький memory footprint, добре на ARM |
| C5 — Security | 4/5 | Memory safety (GC); supply chain простіший (менше залежностей у проектах); хороший токсон-моніторинг |
| C6 — Productivity апліканта | 3/5 | Аплікант знає Go, але не основний стек |
| C7 — Adoption | 3.5/5 | Менший пул контриб'юторів, ніж Python/TS |

**Weighted score: 0.20×3 + 0.18×3 + 0.15×5 + 0.12×4.5 + 0.15×4 + 0.12×3 + 0.08×3.5 = 3.62/5**

### 5.3. Плюси

- Найкращий deployment story з усіх кандидатів.
- Швидко, передбачувано, low resource.
- Хороша concurrency story для consent gateway.

### 5.4. Мінуси

- Менш зрілий MCP SDK — більше ризику доводити SDK-bugs.
- FHIR-екосистема не така багата.
- Аплікант менш продуктивний.

---

## 6. Кандидат 4: Rust

### 6.1. Що це

- **Rust 1.80+** (stable).
- MCP: `rmcp` ([github.com/modelcontextprotocol/rust-sdk](https://github.com/modelcontextprotocol/rust-sdk)) — офіційний від Anthropic (з кінця 2024 — рання, але швидко зріє). Альтернатива: `mcp-sdk-rs` (community).
- FHIR-екосистема: `fhirbolt` (R4/R4B/R5 strong-typed models), `fhir-r4` (alternative), `fhirpath-rs`. Молодша за Python, але є.
- Web framework: Axum (з tower middleware ecosystem) або Actix-web.
- Storage: `rusqlite` + `sqlcipher` бакенд або application-layer `aes-gcm` крате.
- OAuth: `oauth2` crate.
- Packaging: native single static binary (з musl — повністю static), ~5-15MB. Cross-compile через cargo-zigbuild.

### 6.2. Оцінка

| Критерій | Бал | Пояснення |
|----------|-----|-----------|
| C1 — MCP SDK | 3.5/5 | `rmcp` офіційний, але молодший за Python/TS. Активний розвиток. Готовий для production з certain caveats |
| C2 — FHIR екосистема | 3/5 | `fhirbolt` strong-typed і добре сконструйований, але вужчий, ніж Python. Бракує мовних інструментів і community resources |
| C3 — Deployment | 5/5 | Native single binary, найменший footprint з усіх. Йоганн отримує ~10MB executable |
| C4 — Performance | 5/5 | Найкраще з усіх. CPU-bound FHIR парсинг у 5-10× швидше Python. Зайчатник на Raspberry Pi |
| C5 — Security | 5/5 | Memory safety без GC; найкращий supply chain story у sysprog (cargo audit, crev), zero-cost abstractions, audit-friendly |
| C6 — Productivity апліканта | 2.5/5 | Аплікант має базове знайомство з Rust, але не основний стек. Learning curve додасть ~3-4 тижні для production code |
| C7 — Adoption | 3/5 | Менший пул контриб'юторів у health-домені; Rust loved by engineers, але less plug-and-play |

**Weighted score: 0.20×3.5 + 0.18×3 + 0.15×5 + 0.12×5 + 0.15×5 + 0.12×2.5 + 0.08×3 = 3.93/5**

### 6.3. Плюси

- Найкращий deployment + performance + security mix.
- Memory safety без GC — критично для PHI-handling code (немає тимчасових копій у GC-heap, easier to audit).
- Single static binary з найменшим footprint.
- Rust має сильний адопшн у privacy-focused community (Signal protocol implementations, AGE encryption, etc.) — це alignment with project ethos.
- Reasoning-friendly мова — менше runtime surprises, що цінно для аудит-orientovannogo проекту.

### 6.4. Мінуси

- Learning curve — найвищий з кандидатів.
- FHIR-екосистема — найвужча.
- 6 PM з Rust = ~5 PM з Python через learning і recodeerings.
- Менше доступних контриб'юторів.
- Якщо потрібен Python-only FHIR-tool (`smart-on-fhir` for testing) — треба FFI bridges або subprocess.

---

## 7. Зведена матриця

| Критерій (вага) | Python | TypeScript | Go | Rust |
|-----------------|--------|------------|-------|------|
| MCP SDK (0.20) | 5 | 5 | 3 | 3.5 |
| FHIR (0.18) | 5 | 3 | 3 | 3 |
| Deployment (0.15) | 3 | 3.5 | 5 | 5 |
| Performance (0.12) | 3 | 3.5 | 4.5 | 5 |
| Security (0.15) | 3.5 | 3 | 4 | 5 |
| Productivity (0.12) | 5 | 3.5 | 3 | 2.5 |
| Adoption (0.08) | 5 | 4 | 3.5 | 3 |
| **Weighted score** | **4.27** | **3.61** | **3.62** | **3.93** |

---

## 8. Прийняте рішення і обґрунтування

### 8.1. Decision: Rust + `rmcp` з самого початку (M1)

**Чому Rust переважив, попри нижчий weighted score:**

1. **Weighted score не врахував архітектурну вісь project thesis.** Проект продає аудиторії "self-hosted privacy-by-architecture". Найслабше місце цієї історії — deployment friction. Python deployment ("docker compose" або "PyInstaller bundle") не дозволяє Йоганн-persona (71 рік, low-tech) встановити софт без сторонньої допомоги. Rust single static binary `myhealth.exe` (~10-15MB) — дозволяє. Це не "nice-to-have", це core value prop.

2. **Memory safety без GC** має непропорційно велике значення для health-софту з PHI. Аудитор, який буде на M8 перевіряти консент-гейтвей і store, може довіряти, що Rust-код не має use-after-free, double-free, або race conditions у `unsafe`-free коді. Це коротший аудит-звіт і менше middle-severity findings, що зрушують M9 release.

3. **Resource footprint важливий для Raspberry Pi/NAS-deployments.** Цільова аудиторія включає Personas, які запускають на home-server (Synology, TrueNAS). Rust binary з 5-15MB RAM idle проти Python з 80-100MB — це різниця між "впишеться у 2GB Pi разом з іншими сервісами" і "доведеться окремий пристрій".

4. **Phase 2 rewrite — це false economy.** Якщо стартувати на Python з планом "переписати hot-path на Rust на M5-M6", то на практиці виходить два паралельних кодбази, FFI bridges, два набори tests, два supply chains. Стратегічна боргова петля, з якої виходять у фазі 3 повним rewrite. Краще заплатити inception cost один раз на M1.

5. **Long-term contributor pool.** Rust-екосистема у privacy/health просторі швидко зростає у 2025-2026 (Signal, Bitwarden Rust core, Age, тощо). Через 12-18 місяців контриб'юторський пул у нашому домені на Rust порівняється з Python, а можливо й перевершить.

### 8.2. Що коштує це рішення (явно)

- **~2-3 додаткових тижні inception** на M1: Rust scaffolding, `rmcp` ramp-up, `fhirbolt` learning. Включено у бюджет M1 buffer.
- **~1-2 тижні на FHIR-адаптери** через вужчу екосистему, ніж Python. Mitigated тим, що FHIR R4 schema стабільна — раз парсер написаний, він не вимагає constant maintenance.
- **Менший пул контриб'юторів у перший рік.** Mitigation: чистий, добре документований код; explicit "good first issues"; participation у Rust-health Working Group.
- **Productivity апліканта.** Аплікант має 11+ років sysops-фундаменту і 3+ роки MCP-розробки; Rust — нова мова, але не нова парадигма. Ramp-up — здоланий.

### 8.3. Виграші, проти яких коштує платити

- **Single static binary deployment.** Йоганн отримує `myhealth.exe`/`.dmg`/`.AppImage` і не торкається Docker.
- **Найкращий security baseline.** Memory safety без runtime; `cargo audit` для supply chain; `unsafe` блоки явні і review-able.
- **Найменший footprint.** Працює на Raspberry Pi 4 (2GB) з head room.
- **Reasoning-friendly мова.** Менше runtime surprises, що цінно для аудит-orientовaного проекту.
- **Alignment with privacy ethos.** Signal, AGE, Bitwarden core — usі Rust. Наш проект логічно вписується.
- **Performance як побічний бонус.** p99 latency не буде blocker-ом ніколи.

### 8.4. Не рекомендовано TypeScript і Go

- **TypeScript** не виграє у жодному критерії. Програє Python у FHIR, Rust у deployment/security.
- **Go** виграє у deployment (близький до Rust), але MCP SDK і FHIR-екосистема слабші, а security baseline без явного `unsafe` boundary робить аудит менш чітким.

### 8.5. Що було б по-іншому, якщо б ми обрали Python

- Швидше до working demo (на ~2-3 тижні).
- Більше потенційних контриб'юторів у фазі 1.
- Складніший deployment story → менший пул кінцевих користувачів.
- Phase 2 rewrite-tax майже неминучий.
- Більший supply chain attack surface.

Це trade-off, який ми робимо свідомо: trade ~3 тижні inception на стратегічно правильний deployment + security baseline.

---

## 9. Конкретний tech-stack (Rust)

### 9.1. Server-side (Rust)

| Шар | Crate | Версія | Призначення |
|-----|-------|--------|-------------|
| Toolchain | Rust stable | 1.80+ | Основний |
| Async runtime | `tokio` | latest | Concurrent agents/HTTP |
| MCP server | `rmcp` (офіційний від Anthropic) | latest | MCP protocol implementation |
| FHIR models | `fhirbolt` | latest R4 | Strong-typed FHIR R4 (R5 додаємо у фазі 2) |
| FHIR validation | `fhirbolt-shared` + custom validators | latest | Schema + business rule validation |
| Web framework | `axum` + `tower` middleware | latest | UI backend, OAuth endpoints |
| HTTP runtime | `hyper` | latest | Через `axum`/`tokio` |
| Serialization | `serde` + `serde_json` | latest | JSON in/out |
| Storage driver | `rusqlite` (з `bundled-sqlcipher` feature) | latest | SQLite + encryption-at-rest |
| Encryption | `aes-gcm` + `argon2` + `chacha20poly1305` (опційно) | latest crates | AES-256-GCM + Argon2id KDF |
| Key management | `secrecy` + `zeroize` | latest | Зануляння ключів у пам'яті, mlock де можливо |
| OAuth | `oauth2` + custom JWT signing | latest | Consent gateway |
| JWT | `jsonwebtoken` | latest | Tokens з HMAC-SHA256 |
| Logging | `tracing` + `tracing-subscriber` (JSON output) | latest | Structured JSON logs |
| Testing | `cargo test` + `proptest` + `criterion` | latest | Unit + property-based + benchmarks |
| Lint | `clippy` (deny warnings on main) | latest | Static analysis |
| Format | `rustfmt` | latest | Format |
| Security scan | `cargo-audit` + `cargo-deny` | latest | CVE check + dep policy |
| FFI (опційно) | `pyo3` або subprocess | — | Якщо потрібна Python-tool інтеграція для тестування |
| Cross-compile | `cargo-zigbuild` + `cross` | latest | Linux/macOS/Windows × x86_64/aarch64 |
| Packaging | Native binary + Docker (multi-stage) | — | Distribute |
| Installer (desktop) | `tauri-bundler` для .msi/.dmg/.AppImage/.deb (ADR-008); WiX + cargo-bundle лишається як fallback | latest | End-user desktop installers через Tauri-shell поверх axum |
| Installer (server/headless) | Docker multi-stage image + raw `.deb`/`.rpm` для server-сценаріїв (B, C) | — | Server-deployments не використовують Tauri-shell — bare Rust binary |
| CI | GitHub Actions з matrix builds | — | Build, test, sign |
| Releases | `cosign` signed | — | Supply chain integrity (SLSA Level 2 ціль) |
| SBOM | `cargo-cyclonedx` (SBOM у CycloneDX format) | latest | REUSE + SBOM compliance |

### 9.2. Frontend stack (UI client)

UI client — web-stack, server-driven MPA через htmx (ADR-007 у `06-architecture.md`). Rust-у-браузері (через WASM) — overkill для нашого scope; browser — найкращий cross-platform UI runtime для self-hosted.

| Шар | Технологія | Призначення |
|-----|-----------|-------------|
| Framework | Vanilla JS + htmx (закріплено, ADR-007) | Server-driven MPA, мінімум build-кроків, transparent для аудиту |
| Точковий escape valve | Alpine.js islands | Для timeline-візуалізацій лабораторних показників, якщо потрібен richer client state. Стек не переписуємо |
| Styling | PicoCSS (semantic, classless baseline) + точкові utility класи | Мінімалістично, без Tailwind build pipeline |
| Bundling | None — htmx через `<script>` tag з self-hosted CDN-copy; assets embed-имо у Rust binary через `rust-embed` | Zero JS build step як baseline; якщо Alpine.js island виросте — додаємо `esbuild` cmd, не цілий pipeline |
| i18n | Server-side через `axum` + JSON resource bundles (UA, EN, EE, DE, PL) | Рендеримо locale-resolved HTML, не клієнтський i18n |
| Accessibility | `axe-core` у CI на rendered HTML | WCAG 2.1 AA |
| Serving | Через `axum` static-file handler з embedded assets | Single binary deployment без external file deps |

### 9.3. Native installer wrappers

Desktop-сценарії використовують Tauri-shell поверх axum UI backend (ADR-008 у `06-architecture.md`). Server-сценарії (Docker, NAS) ставлять той самий Rust-binary без Tauri-shell — binary self-sufficient.

| Платформа | Інструмент | Артефакт | Сценарій |
|-----------|-----------|----------|----------|
| Windows desktop | `tauri-bundler` (MSI/NSIS) + signed з cert | `MyHealth-Europe-1.0.msi` | A — Йоганн |
| macOS desktop | `tauri-bundler` (.dmg) + notarization + Apple Developer ID | `MyHealth-Europe-1.0.dmg` | A — Йоганн |
| Linux desktop | `tauri-bundler` (.AppImage, .deb для GUI desktop) | `MyHealth-Europe-1.0.AppImage`, `myhealth-europe-desktop-1.0_amd64.deb` | A — Йоганн на Linux |
| Linux server (headless) | Pure Rust binary без Tauri-shell + Docker image | `myhealth-europe-server-1.0_amd64.deb`, `myhealtheurope/server:1.0` | B, C — Анна, Ольга |
| ARM (Raspberry Pi, NAS) | Static binary без Tauri через `cargo-zigbuild --target aarch64-unknown-linux-musl` | `myhealth-europe-1.0-aarch64-linux` | C — community NAS-deployments |

Fallback план (якщо Tauri почне ламатись на якійсь платформі): WiX 4 для Windows, `cargo-bundle` для macOS, raw AppImage для Linux. Це опис плану B, не основний шлях.

---

## 10. Ramp-up і ризик-менеджмент

Оскільки Rust для апліканта — не основний стек, M1 має explicit ramp-up частину з контрольними точками.

### 10.1. M1 ramp-up план (перші 4 тижні)

| Тиждень | Активність | Deliverable |
|---------|-----------|-------------|
| 1 | Rust scaffolding: `cargo new`, CI baseline, `clippy` strict, `tracing` setup | Repo з working CI |
| 1-2 | `rmcp` minimal example — hello-world MCP сервер з 1 фіктивним tool | Echo-tool через MCP Inspector |
| 2 | `fhirbolt` proof — парсинг sample FHIR R4 bundle (наприклад, synthetic Synthea) | Демо: bundle.json → typed structs |
| 2-3 | `rusqlite` + encryption proof — encrypted SQLite з AES-GCM записом resource | Smoke-test write/read encrypted record |
| 3 | `axum` UI backend skeleton — статичний asset serve + REST endpoint | Локальний UI відкривається |
| 4 | Інтеграція всіх компонентів у one-binary smoke test | End-to-end: import sample → query → MCP tool returns |

Якщо у кінці тижня 4 smoke-test проходить — продовжуємо за planom. Якщо ні — escalation у team review, можливе перепозиціонування плану.

### 10.2. Контрольні точки

- **Кінець тижня 2:** якщо `rmcp` або `fhirbolt` мають blocker-bug — escalation. Резервний план: switch на Python з планом Rust-rewrite на phase 2 (це той самий план, який ми відкинули, але як emergency exit).
- **Кінець M1:** working repo з CI, signed releases workflow, baseline smoke test.
- **M2 кінець:** один FHIR-адаптер (eHealth UA) повністю реалізований і tested.

### 10.3. Чи потрібен Python для test-tools

Так, але як зовнішня dev-залежність, не як runtime. Конкретно:
- **`smart-on-fhir/test-data`** (Python tools) — для генерації synthetic FHIR bundles для тестування.
- **HL7 Validator (Java) або equivalent** — для cross-validation наших FHIR-output-ів.

Ці інструменти запускаються у CI як subprocess, не linked у production binary.

---


## 11. Відкриті питання для team review

1. ~~**Frontend stack:** vanilla JS + htmx чи SvelteKit?~~ **Закрито 2026-05-12: htmx (ADR-007).** Server-driven MPA, Alpine.js islands як точковий escape valve. SvelteKit відкинуто через Node toolchain і npm supply chain (зиск у нашому UI-скоупі не виправдовує тезу single binary).
2. ~~**Installer вибір:** Tauri wrapper чи прості native installers?~~ **Закрито 2026-05-12: Tauri (ADR-008).** Desktop UX для непрофільної аудиторії пацієнтів важливіша, ніж кілька MB додаткового binary; Tauri — сам Rust-проєкт, зберігає Rust-first ethos. WiX + cargo-bundle лишається як fallback.
3. ~~**Database choice — SQLCipher vs application-layer AES-GCM:**~~ **Закрито 2026-05-12: hybrid (ADR-009).** SQLCipher full-DB encryption як baseline + application-layer AES-GCM для найчутливіших PHI-полів (defense-in-depth + per-record key rotation для GDPR erasure). Pure-Rust теза переоцінена (TLS-стек все одно тягне C-залежність).
4. **Rust async ecosystem stability:** `tokio` як де-факто standard — OK. Перевірити, що `rmcp` сумісний (так, основано на `tokio`).

---

*Це рішення прив'язане до бюджету (6 PM principal engineer) і команди (1 повний + 1 part-time субконтрактор). Якщо обсяг ресурсів зміниться (наприклад, у фазі 2 — €100K, 2 повних engineer), `02-prd.md` і цей документ оновлюються відповідно.*

*Дивись: [06-architecture.md](06-architecture.md) для компонентної декомпозиції; [02-prd.md](02-prd.md) для функціональних вимог, які стек повинен задовольнити.*
