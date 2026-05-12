# 02 — Product Requirements Document (PRD)

**Документ:** MyHealth-Europe — продуктові вимоги
**Версія:** 0.1
**Дата:** 12 травня 2026
**Власник:** Руслан Грибан
**Прив'язка до грантового драфту:** milestone-и M1-M9 у [`../../NGI-CommonsFund-13-DRAFT-2026-05-08.md`](../../NGI-CommonsFund-13-DRAFT-2026-05-08.md), розділ 5.

---

## TL;DR (для комісії)

Продукт складається з шести функціональних блоків: (1) FHIR-імпортери з трьох джерел, (2) зашифроване локальне сховище, (3) MCP-сервер з tools-поверхнею для AI-агентів, (4) OAuth 2.1 consent gateway з time-bound токенами, (5) reference UI клієнт для self-hosted використання, (6) reference cross-border navigation агент. Кожен блок прив'язано до конкретного milestone у грантовому драфті з критеріями приймання.

Ключові нефункціональні вимоги: privacy-by-architecture (немає бекенду проекту), self-hostability (Docker + native binary), accessibility (WCAG 2.1 AA для UI), low resource footprint (працює на Raspberry Pi 4), і untrusted-client model (припускаємо, що AI-агент може бути зловмисний).

---

## 1. Огляд продукту

### 1.1. Що це

Open-source software-bundle, який громадянин ЄС встановлює у себе. Складається з server-процесу (MCP-сервер), local-only веб-UI, набору CLI-команд для імпорту/експорту, та reference AI-агента, який демонструє патерн end-to-end.

### 1.2. Як виглядає для користувача

```
$ docker compose up -d myhealth-europe
$ open http://localhost:7777
[UI: "Welcome. Step 1: import your data"]
$ myhealth import digilugu ~/Downloads/digilugu-export.json
Imported 245 records from Estonia Digilugu.
$ open claude://
[у Claude Desktop:] "Підсумуй мої результати лабораторії за 6 міс"
[Claude:] "Запитую дозвіл на читання Observation з category=lab..."
[UI випливає prompt:] "Approve? [Yes 1h] [Yes 24h] [No]"
[Користувач натискає Yes 1h]
[Claude отримує дані, формує summary]
```

### 1.3. Хто типовий користувач

- **Persona A — «Анна, expat у Берліні»:** 34 роки, IT-аналітикиня, переїхала з Києва у 2023. Має записи в eHealth UA (стара історія) і у німецькому ePA (нові). Хоче AI-помічника, який може відповісти на питання типу «коли мені робили щеплення від кашлюка» (відповідь — у українських записах) англійською або німецькою.
- **Persona B — «Йоганн, пенсіонер з Мюнхена»:** 71 рік, проводить зими в Аліканте, лікується там у місцевого терапевта. Хоче, щоб AI допоміг порівняти його німецькі і іспанські призначення (потенційні взаємодії, дублікати).
- **Persona C — «Ольга, медсестра з Естонії з хронічним станом»:** 42 роки, активний користувач Digilugu, цікавиться local-LLM (Llama на власному ноутбуці). Хоче запитати приватного агента, не передаючи дані cloud-провайдеру.

---

## 2. Функціональні вимоги (FR)

Нумерація: `FR-X.Y` де X — модуль, Y — конкретна вимога.

### 2.1. Модуль 1: FHIR-імпортери

| ID | Вимога | Acceptance criteria | Milestone |
|----|--------|--------------------|-----------|
| FR-1.1 | Імпорт FHIR R4 bundle з файлу | CLI команда `myhealth import <source> <path>`; UI upload form; парсинг JSON; валідація проти R4 schema | M2 |
| FR-1.2 | Адаптер для eHealth Україна | Приймає NSZU-FHIR export, нормалізує NSZU extensions, конвертує дати, мовну розмітку | M2 |
| FR-1.3 | Адаптер для Estonia Digilugu | Приймає Digilugu FHIR bundle, обробляє CDA→FHIR для legacy records | M2 |
| FR-1.4 | Адаптер для Apple Health | Приймає Apple Health Export ZIP, конвертує XML у FHIR Observation/Condition | M2 |
| FR-1.5 | Idempotent re-import | При повторному імпорті того ж файлу — `count_new=0`, `count_existing=N`, без дублікатів | M2 |
| FR-1.6 | Імпорт-summary | Після імпорту — звіт: кількість по resource type, диапазон дат, виявлені помилки валідації | M2 |
| FR-1.7 | Партіальне відновлення | Якщо у bundle частина records невалідна — імпортуються валідні, невалідні складаються у quarantine з причиною | M3 |

### 2.2. Модуль 2: Local store

| ID | Вимога | Acceptance criteria | Milestone |
|----|--------|--------------------|-----------|
| FR-2.1 | Зберігання у SQLite | SQLite DB-файл, hybrid encryption-at-rest: SQLCipher full-DB (baseline) + application-layer AES-GCM column-level для найчутливіших PHI-полів (defense-in-depth, GDPR-erasure через per-record key rotation). ADR-009 у `06-architecture.md`. | M3 |
| FR-2.2 | Ключ шифрування деривується з user passphrase | Argon2id (≥64MB memory, ≥3 iterations); ключ ніколи не записується на диск; reset = data loss | M3 |
| FR-2.3 | Query API на FHIR-resource рівні | Внутрішнє API: `get_observations(filter)`, `get_conditions(filter)`, `get_medications(filter)`, etc. | M3 |
| FR-2.4 | p99 latency < 200ms на 1000-record dataset | Бенчмарк-suite у CI | M3 |
| FR-2.5 | Backup / restore | `myhealth backup --out file.enc` створює encrypted backup; `restore` повертає | M9 |
| FR-2.6 | Soft delete + hard delete | Видалення спочатку soft (recoverable 30 days), потім hard | M9 |

### 2.3. Модуль 3: MCP-сервер

| ID | Вимога | Acceptance criteria | Milestone |
|----|--------|--------------------|-----------|
| FR-3.1 | Сумісність із MCP spec v0.6+ | Проходить MCP Inspector test-suite | M4 |
| FR-3.2 | Транспорт: stdio | Standard MCP stdio transport works з Claude Desktop | M4 |
| FR-3.3 | Транспорт: SSE/HTTP | Для remote-client сценаріїв (з consent від користувача) | M4 |
| FR-3.4 | Tools: read-only поверхня | `get_observations`, `get_conditions`, `get_medications`, `get_allergies`, `get_immunizations`, `get_encounters`, `get_diagnostic_reports`, `search_records` | M4 |
| FR-3.5 | Tool: `get_health_summary` | Структурований overview без сирих PHI (count by category, date ranges) — для агентів, які хочуть обрати scope інтелігентно | M4 |
| FR-3.6 | Resources: published examples | `health://schema/observation`, `health://examples/sample` — sample resources для agent learning | M4 |
| FR-3.7 | Prompts: reference prompts | Pre-built prompts для типових запитів (summary, medication-reconciliation, lab-trend) | M4 |
| FR-3.8 | Write-back операції | **Не у фазі 1.** Out of scope до фази 2 | — |

### 2.4. Модуль 4: Consent gateway

| ID | Вимога | Acceptance criteria | Milestone |
|----|--------|--------------------|-----------|
| FR-4.1 | OAuth 2.1 token issuance | Стандартний OAuth 2.1 flow для AI-агента; refresh tokens; PKCE | M5 |
| FR-4.2 | Scope-by-resource-type | Scope strings: `read:observations:lab`, `read:medications:active`, etc. Granularity по category | M5 |
| FR-4.3 | Time-bound токени | TTL у presets: 5 min, 1h, 24h, 7d, persistent (з warning); максимум 30 діб | M5 |
| FR-4.4 | One-click revoke | UI sessions list з revoke button; програмний revoke endpoint | M5 |
| FR-4.5 | Per-resource-type confirmation | Якщо агент запитує scope, який охоплює sensitive categories (psych, sexual, genetic) — додатковий confirmation step | M5 |
| FR-4.6 | Аудит-лог запис | Кожен grant/deny/revoke/read — окремий event у append-only log | M5 |
| FR-4.7 | Threat model задокументований | STRIDE для consent gateway; `08-threat-model.md` оновлено | M5 |
| FR-4.8 | Pen-test пройдено | Зовнішній пен-тест consent flow перед M8 | M8 |

### 2.5. Модуль 5: Reference UI client

| ID | Вимога | Acceptance criteria | Milestone |
|----|--------|--------------------|-----------|
| FR-5.1 | Web UI на localhost:7777 (default) | Працює offline; немає external CDN dependencies; bundled assets | M6 |
| FR-5.2 | Setup wizard | Перший запуск — passphrase, бек-стори, importer выбір | M6 |
| FR-5.3 | Import workflow | Drag-and-drop file → adapter detection → import progress → summary | M6 |
| FR-5.4 | Records browser | Перегляд records по category, date, source; пошук по тексту | M6 |
| FR-5.5 | Sessions / consent management | Active sessions list, history, revoke | M6 |
| FR-5.6 | Аudit-log viewer | Filterable view audit events; export як CSV/JSON | M6 |
| FR-5.7 | Settings | Tema, мова інтерфейсу (UA/EN/EE/DE/PL), backup config | M6 |
| FR-5.8 | WCAG 2.1 AA | Automated (axe-core) + manual screen-reader test pass | M6 |
| FR-5.9 | i18n: 5 мов на release | UA, EN, EE, DE, PL у v1.0 | M9 |
| FR-5.10 | User testing (n≥10) | Юзабіліті-тест перед M7, фідбек інтегровано | M6 |

### 2.6. Модуль 6: Reference cross-border navigation agent

| ID | Вимога | Acceptance criteria | Milestone |
|----|--------|--------------------|-----------|
| FR-6.1 | UA-EE пілот flow | End-to-end: імпорт UA + EE → агент відповідає на «безперервність призначень» | M7 |
| FR-6.2 | Перевірка призначень | Знаходить активні призначення у обох системах, порівнює, виявляє можливі взаємодії (за внутрішньою бібліотекою або EU-published drug interaction DB) | M7 |
| FR-6.3 | Мовний міст | Запит UA → відповідь UA; запит EN → відповідь EN; з record-level translation тільки де треба | M7 |
| FR-6.4 | Підготовка документа для нового сімейного лікаря | Структурований PDF/HTML з основною історією, призначеннями, алергіями, мовою країни destination | M7 |
| FR-6.5 | Прозорість моделі | UI показує, яка модель використана, де живе, що передано | M7 |
| FR-6.6 | Deployment через HealBot.pro | Reference deployment живий у HealBot.pro infra з реальним user testing | M7 |

### 2.7. Модуль 7: Документація і replication kit

| ID | Вимога | Acceptance criteria | Milestone |
|----|--------|--------------------|-----------|
| FR-7.1 | README з 5-min quickstart | Від `git clone` до робочого імпорту за <5 хв на typical laptop | M9 |
| FR-7.2 | Deployment guide | Docker compose, native binary, Raspberry Pi, NAS-deployment | M9 |
| FR-7.3 | Adapter development guide | Гайд для написання нового FHIR-адаптера (приклад: «як додати свою країну») | M9 |
| FR-7.4 | API reference | OpenAPI + MCP-tools reference з прикладами | M9 |
| FR-7.5 | Replication kit | Standalone bundle з sample data, deployment config, demo сценарії, замінник branding | M9 |
| FR-7.6 | Security baseline doc | Threat model + audit findings + remediation history публічно | M9 |

---

## 3. Нефункціональні вимоги (NFR)

### 3.1. Security & Privacy

| ID | Вимога | Як перевіряємо |
|----|--------|----------------|
| NFR-S1 | Encryption-at-rest для всіх PHI | Інспекція DB-файлу: жодного plaintext PHI |
| NFR-S2 | Encryption-in-transit для UI ↔ server | TLS для non-localhost; localhost дозволено plaintext |
| NFR-S3 | No phone-home | Network egress monitoring у CI: no outbound connections від server process крім явних user-initiated |
| NFR-S4 | Supply chain | SBOM з кожним release; signed releases (cosign); dependabot |
| NFR-S5 | No telemetry by default | Default config: telemetry=disabled |
| NFR-S6 | OWASP ASVS L2 baseline | Self-assessment + external audit |
| NFR-S7 | Secret scanning у CI | Trufflehog/Gitleaks pre-commit і CI |

### 3.2. Performance

| ID | Вимога | Цільове |
|----|--------|---------|
| NFR-P1 | FHIR query p99 latency | <200ms на 10K-record dataset |
| NFR-P2 | Import 1000 records | <30s |
| NFR-P3 | Memory footprint у idle | <100MB RSS |
| NFR-P4 | Disk footprint без даних | <100MB |
| NFR-P5 | Cold start | <3s |
| NFR-P6 | Працює на Raspberry Pi 4 (2GB) | Smoke-тест у CI |

### 3.3. Reliability

| ID | Вимога | Цільове |
|----|--------|---------|
| NFR-R1 | Atomic write до store | Crash-safe: kill -9 під час import не залишає corrupt store |
| NFR-R2 | Backup integrity | Restore-test у CI: backup → restore → assert equal |
| NFR-R3 | Version migrations | Schema changes мають реверсивні міграції |

### 3.4. Usability

| ID | Вимога | Цільове |
|----|--------|---------|
| NFR-U1 | WCAG 2.1 AA | axe-core score = 0 errors; manual test pass |
| NFR-U2 | i18n | UA, EN, EE, DE, PL у v1.0 |
| NFR-U3 | Onboarding time | Новий користувач: від install до перший імпорт <15 хв |

### 3.5. Operability

| ID | Вимога | Цільове |
|----|--------|---------|
| NFR-O1 | Single-container deployment | `docker run myhealth-europe:latest` достатньо |
| NFR-O2 | Native binary | Linux/macOS/Windows x86_64 + ARM64 |
| NFR-O3 | Logging | Structured JSON logs; configurable level; no PHI у logs |
| NFR-O4 | Health-check endpoint | `/healthz` без auth для liveness |
| NFR-O5 | Graceful shutdown | SIGTERM → flush аудит → завершити запити → exit |

### 3.6. Maintainability

| ID | Вимога | Цільове |
|----|--------|---------|
| NFR-M1 | Test coverage | Лінії: ≥80%; branches: ≥70% |
| NFR-M2 | Lint clean | 0 lint warnings на main |
| NFR-M3 | Documented public API | 100% public functions/classes — doc comments |
| NFR-M4 | Architecture decision records | ADRs для всіх non-trivial choices у `docs/adr/` |

---

## 4. Залежності між модулями (порядок реалізації)

```
M1 (repo + CI)
   │
   ▼
M2 (FHIR-імпортери) ─────────► M3 (local store)
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
                                                     M8 (security audit)
                                                          │
                                                          ▼
                                                     M9 (docs, replication, v1.0)
```

Це критичний шлях — затримка будь-якого блоку зрушує всю гілку.

---

## 5. Acceptance criteria на release v1.0

Реліз v1.0 (M9) випускається, ЯКЩО:

1. Усі FR з фази 1 (FR-1.* до FR-7.*) реалізовані і покриті тестами.
2. Усі medium+ findings security audit закрито.
3. p99 latency < 200ms підтверджено бенчмарком.
4. Reference agent demonstrates end-to-end UA-EE flow на live (або реалістичній test) infrastructure.
5. ≥3 downstream-впроваджувачі підтвердили інтерес письмово (не обов'язково deployed).
6. Документація проходить test: новий розробник може зробити quickstart і написати свій адаптер за 1 день.

---

## 6. Out-of-scope (явно НЕ робимо у фазі 1)

- Write-back до національних e-health систем.
- Live FHIR API коннектори (бо це per-provider OAuth і operational complexity).
- Mobile-нативні клієнти (тільки web UI у фазі 1).
- Adapter-и поза 3 запланованими (PL, DE, FR — фаза 2).
- Cluster / multi-user deployments.
- Hosted SaaS-deployment (це може зробити downstream).
- Клінічні моделі або інтегровані LLM (це робота агента-користувача).

---

*Дивись: [01-business-requirements.md](01-business-requirements.md) для бізнес-контексту; [06-architecture.md](06-architecture.md) для компонентної декомпозиції; [05-tech-stack.md](05-tech-stack.md) для tech-stack рекомендації.*
) для компонентної декомпозиції; [05-tech-stack.md](05-tech-stack.md) для tech-stack рекомендації.*
