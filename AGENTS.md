# AGENTS.md

> Карта проекту для AI-агентів. Тримай актуальною — оновлюй при значущих структурних змінах.
> Підтримується через `/aif-docs`. Локалізовано українською (відповідно до `language.artifacts: uk`).

## Огляд проекту

**MyHealth-Europe** — open-source MCP-сервер на Rust, який громадянин ЄС запускає у себе для надання AI-агентам обмеженого, аудит-логованого доступу до своїх FHIR-записів. Privacy-by-architecture, не privacy-by-policy. Pre-implementation, design phase (вихідного коду ще немає).

Деталі: [.ai-factory/DESCRIPTION.md](.ai-factory/DESCRIPTION.md).

## Стек технологій

- **Мова:** Rust stable 1.80+
- **Async runtime:** `tokio`
- **MCP server:** `rmcp` (офіційний від Anthropic)
- **FHIR models:** `fhirbolt` (R4)
- **Web framework:** `axum` + `tower`
- **Storage:** `rusqlite` з `bundled-sqlcipher` (SQLite + encryption-at-rest)
- **Encryption:** `aes-gcm` + `argon2` + `secrecy` + `zeroize`
- **OAuth:** `oauth2` + `jsonwebtoken`
- **UI:** htmx + server-driven MPA (через `axum`)
- **Desktop installer:** `tauri-bundler`
- **Testing:** `cargo test` + `proptest` + `criterion`
- **Lint / format:** `clippy` (deny warnings) + `rustfmt`
- **CI:** GitHub Actions з matrix builds; signed releases через `cosign`; SBOM через `cargo-cyclonedx`

Повна таблиця: [.ai-factory/DESCRIPTION.md § Стек технологій](.ai-factory/DESCRIPTION.md#стек-технологій-закріплено-2026-05-12).

## Структура проекту (поточна)

```
myhealth-europe/
├── README.md                    # Landing-сторінка (UA), TL;DR і навігація по docs/
├── AGENTS.md                    # Цей файл — карта для AI-агентів
├── .ai-factory/                 # AI Factory artifacts
│   ├── config.yaml              # Налаштування AI Factory (мови, шляхи, git)
│   ├── DESCRIPTION.md           # Project specification (WHAT + WHY)
│   ├── ARCHITECTURE.md          # (буде створено через /aif-architecture)
│   └── rules/
│       └── base.md              # Базові project conventions
├── .ai-factory.json             # AI Factory installer state (skills + MCP)
├── .claude/                     # Claude Code agent context
│   ├── skills/                  # Встановлені AI Factory skills (aif-*)
│   └── agents/                  # Sidecar/coordinator agent files
├── .codex/                      # Codex agent context
│   └── skills/                  # Дзеркало AI Factory skills для Codex
├── .mcp.json                    # MCP-сервери (github, filesystem, postgres, chromeDevtools, playwright)
├── .gitignore                   # Rust + Tauri + IDE + secrets + DB ignores
├── .gitattributes               # Git attributes
└── docs/                        # Pre-implementation документація (UA)
    ├── 01-business-requirements.md  # BRD: проблема, аудиторія, цілі, KPI
    ├── 02-prd.md                    # Functional + non-functional requirements (M1-M9)
    ├── 03-data-flow.md              # Звідки беруться дані, що ніколи не виходить
    ├── 04-user-flow.md              # User journeys (інсталяція, імпорт, згода)
    ├── 05-tech-stack.md             # Обґрунтування Rust + rmcp
    ├── 06-architecture.md           # Компоненти, границі довіри, deployment
    ├── 07-licensing-strategy.md     # Apache 2.0 / AGPL 3.0 split
    └── 08-threat-model.md           # STRIDE-аналіз, контрзаходи
```

Планована структура коду після старту M1 — у [.ai-factory/rules/base.md § Структура коду](.ai-factory/rules/base.md#структура-коду-планована).

## Ключові точки входу (поточні)

| Файл | Призначення |
|------|-------------|
| README.md | Project landing page (UA) — TL;DR, ліцензії, навігація, контакт |
| docs/02-prd.md | Канонічний список фіч і acceptance criteria по M1-M9 |
| docs/05-tech-stack.md | Закріплене рішення Rust + `rmcp` (2026-05-12) |
| docs/06-architecture.md | Компоненти, trust boundaries, deployment topology |
| docs/08-threat-model.md | STRIDE для consent gateway, store, MCP-tools |
| .mcp.json | Конфігурація MCP-серверів для Claude Code |
| .ai-factory/config.yaml | UI/artifact language, git workflow, paths |

Точок входу Rust-коду (`main.rs`, `Cargo.toml`) ще немає — з'являться у M1.

## Документація

| Документ | Шлях | Опис |
|----------|------|------|
| README | README.md | Landing page (UA) з TL;DR, ліцензіями, навігацією |
| BRD | docs/01-business-requirements.md | Business Requirements (problem/audience/KPIs) |
| PRD | docs/02-prd.md | Product Requirements (FR/NFR по M1-M9) |
| Data Flow | docs/03-data-flow.md | Найважливіше для комісії — потоки даних |
| User Flow | docs/04-user-flow.md | User journeys (install/import/consent/usage) |
| Tech Stack | docs/05-tech-stack.md | Обґрунтування Rust + `rmcp` |
| Architecture | docs/06-architecture.md | Компоненти, trust boundaries, deployment |
| Licensing | docs/07-licensing-strategy.md | Apache 2.0 / AGPL 3.0 split |
| Threat Model | docs/08-threat-model.md | STRIDE-аналіз, контрзаходи, прив'язка до M5/M8 |

## AI Context файли

| Файл | Призначення |
|------|-------------|
| AGENTS.md | Цей файл — структурна карта проекту для AI-агентів |
| .ai-factory/DESCRIPTION.md | Specification: WHAT (продукт, фічі) + WHY (наміри, NFR) |
| .ai-factory/ARCHITECTURE.md | HOW: Modular Monolith + Hexagonal (Ports & Adapters) — структура crates, dependency rules, code examples, anti-patterns |
| .ai-factory/rules/base.md | Базові project conventions (іменування, errors, logging, testing) |
| .ai-factory/config.yaml | AI Factory налаштування (language: uk, git.create_branches: false, …) |
| .codex/skills/, .claude/skills/ | Встановлені AI Factory skills (aif-*) |

## MCP-сервери (з `.mcp.json`)

| Server | Призначення |
|--------|-------------|
| `github` | GitHub API (потребує `GITHUB_TOKEN` env var) |
| `filesystem` | Розширені файлові операції в проекті |
| `postgres` | Postgres MCP server (потребує `DATABASE_URL` env var) — для майбутніх integration tests |
| `chromeDevtools` | Chrome DevTools для UI-тестування |
| `playwright` | Playwright для browser automation |

## Правила для агентів

- **Мова артефактів:** українська (`language.artifacts: uk`). Технічні терміни (Rust, FHIR, OAuth, MCP, SQLite, axum, rmcp, …) — у оригіналі, не транслітеруються.
- **Мова комунікації:** українська (`language.ui: uk`).
- **Git workflow:** залишаємось на поточній гілці (`git.create_branches: false`); base branch — `main`.
- **Decompose composite shell commands.** Завжди розбивай комбіновані команди на послідовні виклики:
  - ❌ Неправильно: `git checkout main && git pull`
  - ✅ Правильно: спочатку `git checkout main`, потім `git pull origin main`
- **Pre-implementation phase.** Не створюй вихідний код (`crates/*`, `Cargo.toml`, `src/*`) — імплементація стартує тільки після підписання MoU з NLnet (Q3 2026). До того моменту змінюй лише документацію та AI Factory artifacts.
- **PHI-handling principles:** жоден приклад коду не повинен містити реальні або правдоподібні PHI. Використовуй synthetic FHIR fixtures (CC0).
- **No phone-home invariant:** не додавай dependencies, які роблять outbound network calls без явного user-initiated гачка.
- **Documentation-first.** Зміна архітектурного рішення → ADR у `docs/adr/` ПЕРЕД зміною коду.
