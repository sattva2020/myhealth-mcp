# AGENTS.md

> Project map for AI agents. Keep it current — update on any significant structural change.
> Maintained via `/aif-docs`. Localised in English (per `language.artifacts: en`).

## Project overview

**MyHealth-Europe** — an open-source MCP server in Rust that an EU citizen runs at home to give AI agents scope-limited, audit-logged access to their FHIR records. Privacy-by-architecture, not privacy-by-policy. Pre-implementation, design phase (no source code yet).

Details: [.ai-factory/DESCRIPTION.md](.ai-factory/DESCRIPTION.md).

## Tech stack

- **Language:** Rust stable 1.80+
- **Async runtime:** `tokio`
- **MCP server:** `rmcp` (official, by Anthropic)
- **FHIR models:** `fhirbolt` (R4)
- **Web framework:** `axum` + `tower`
- **Storage:** `rusqlite` with `bundled-sqlcipher` (SQLite + encryption-at-rest)
- **Encryption:** `aes-gcm` + `argon2` + `secrecy` + `zeroize`
- **OAuth:** `oauth2` + `jsonwebtoken`
- **UI:** htmx + server-driven MPA (via `axum`)
- **Desktop installer:** `tauri-bundler`
- **Testing:** `cargo test` + `proptest` + `criterion`
- **Lint / format:** `clippy` (deny warnings) + `rustfmt`
- **CI:** GitHub Actions with matrix builds; signed releases via `cosign`; SBOM via `cargo-cyclonedx`

Full table: [.ai-factory/DESCRIPTION.md § Tech stack](.ai-factory/DESCRIPTION.md#tech-stack-locked-in-2026-05-12).

## Project structure (current)

```
myhealth-europe/
├── README.md                    # Landing page (EN), TL;DR and navigation through docs/
├── AGENTS.md                    # This file — map for AI agents
├── .ai-factory/                 # AI Factory artifacts
│   ├── config.yaml              # AI Factory settings (languages, paths, git)
│   ├── DESCRIPTION.md           # Project specification (WHAT + WHY)
│   ├── ARCHITECTURE.md          # Architecture pattern (Modular Monolith + Hexagonal)
│   ├── ROADMAP.md               # M1–M9 milestones with PRD breakdown
│   └── rules/
│       ├── base.md              # Base project conventions (Rust, naming, errors, logging)
│       ├── security.md          # Security area rules (STRIDE-derived, threat model T-*)
│       ├── fhir.md              # FHIR adapter conventions (ports, idempotency, no PHI)
│       └── mcp.md               # MCP tool handler conventions (rmcp, scope, transports)
├── .ai-factory.json             # AI Factory installer state (skills + MCP)
├── .claude/                     # Claude Code agent context
│   ├── skills/                  # Installed AI Factory skills (aif-*)
│   └── agents/                  # Sidecar/coordinator agent files
├── .codex/                      # Codex agent context
│   └── skills/                  # Mirror of AI Factory skills for Codex
├── .mcp.json                    # MCP servers (github, filesystem, postgres, chromeDevtools, playwright)
├── .gitignore                   # Rust + Tauri + IDE + secrets + DB ignores
├── .gitattributes               # Git attributes
├── justfile                     # Build automation (cargo + cross + cargo-llvm-cov)
├── Dockerfile                   # Multi-stage build (builder + development + production)
├── compose.yml                  # Single-service base config (app only, embedded SQLCipher)
├── compose.override.yml         # Dev overrides (bind-mount + cargo-watch + named target volume)
├── compose.production.yml       # Hardening (read_only + cap_drop + tmpfs + resource limits + 127.0.0.1 bind)
├── .dockerignore                # Excludes target/, .ai-factory/, docs/, .git/, secrets
├── .env.example                 # Environment variables template
└── docs/                        # Pre-implementation documentation (EN)
    ├── 01-business-requirements.md  # BRD: problem, audience, goals, KPIs
    ├── 02-prd.md                    # Functional + non-functional requirements (M1–M9)
    ├── 03-data-flow.md              # Where data comes from, what never leaves
    ├── 04-user-flow.md              # User journeys (installation, import, consent)
    ├── 05-tech-stack.md             # Rationale for Rust + rmcp
    ├── 06-architecture.md           # Components, trust boundaries, deployment
    ├── 07-licensing-strategy.md     # Apache 2.0 / AGPL 3.0 split
    └── 08-threat-model.md           # STRIDE analysis, countermeasures
```

Planned code structure after the M1 kick-off — in [.ai-factory/rules/base.md § Code structure](.ai-factory/rules/base.md#code-structure-planned).

## Key entry points (current)

| File | Purpose |
|------|---------|
| README.md | Project landing page (EN) — TL;DR, licenses, navigation, contact |
| docs/02-prd.md | Canonical list of features and acceptance criteria across M1–M9 |
| docs/05-tech-stack.md | Locked-in decision: Rust + `rmcp` (2026-05-12) |
| docs/06-architecture.md | Components, trust boundaries, deployment topology |
| docs/08-threat-model.md | STRIDE for consent gateway, store, MCP tools |
| .mcp.json | MCP server configuration for Claude Code |
| .ai-factory/config.yaml | UI/artifact language, git workflow, paths |

There are no Rust source-code entry points yet (`main.rs`, `Cargo.toml`) — they appear in M1.

## Documentation

| Document | Path | Description |
|----------|------|-------------|
| README | README.md | Landing page (EN) with TL;DR, licenses, navigation |
| BRD | docs/01-business-requirements.md | Business Requirements (problem/audience/KPIs) |
| PRD | docs/02-prd.md | Product Requirements (FR/NFR across M1–M9) |
| Data Flow | docs/03-data-flow.md | Most important for the review committee — data flows |
| User Flow | docs/04-user-flow.md | User journeys (install/import/consent/usage) |
| Tech Stack | docs/05-tech-stack.md | Rationale for Rust + `rmcp` |
| Architecture | docs/06-architecture.md | Components, trust boundaries, deployment |
| Licensing | docs/07-licensing-strategy.md | Apache 2.0 / AGPL 3.0 split |
| Threat Model | docs/08-threat-model.md | STRIDE analysis, countermeasures, linkage to M5/M8 |

## AI context files

| File | Purpose |
|------|---------|
| AGENTS.md | This file — structural map of the project for AI agents |
| .ai-factory/DESCRIPTION.md | Specification: WHAT (product, features) + WHY (intent, NFRs) |
| .ai-factory/ARCHITECTURE.md | HOW: Modular Monolith + Hexagonal (Ports & Adapters) — crate structure, dependency rules, code examples, anti-patterns |
| .ai-factory/ROADMAP.md | Strategic milestones M1–M9 (acceptance criteria, dependencies) |
| .ai-factory/rules/base.md | Base project conventions (naming, errors, logging, testing) |
| .ai-factory/rules/security.md | Security rules (STRIDE-derived, encryption, OAuth, audit log, supply chain) |
| .ai-factory/rules/fhir.md | FHIR adapter conventions (single trait, idempotency, no PHI in logs) |
| .ai-factory/rules/mcp.md | MCP tool handler conventions (rmcp, scope-check, data-block wrapping, rate-limit) |
| .ai-factory/config.yaml | AI Factory settings (language: en, git.create_branches: false, rules.{security,fhir,mcp}) |
| .codex/skills/, .claude/skills/ | Installed AI Factory skills (aif-*) |

## Build commands (`justfile`)

Local dev — via `just <recipe>` (install: <https://github.com/casey/just>).

| Recipe | Purpose |
|--------|---------|
| `just` (= `just check`) | Default gate before commit: fmt-check + lint + test |
| `just help` | List of all recipes |
| `just ci` | Lighter aggregate for CI matrix (without audit/deny/sbom) |
| `just fmt` / `just fmt-check` | `cargo fmt --all` (write / dry-run) |
| `just lint` / `just lint-fix` | `cargo clippy --all-targets --all-features -- -D warnings` (+ `--fix`) |
| `just test` / `just test-doc` | Unit/integration tests / doc-tests across the workspace |
| `just coverage` / `just coverage-ci` | `cargo llvm-cov` HTML / lcov for CI (NFR-M1: ≥80%) |
| `just bench` | `cargo bench` (criterion — NFR-P1: p99 <200ms) |
| `just build` / `just build-release` | Debug build / release build |
| `just cross-linux-arm64` | Raspberry Pi 4 target (NFR-P6); also `cross-linux-x64`, `cross-windows`, `cross-macos-{arm64,x64}` |
| `just run -- <args>` / `just dev` | Run `myhealth-cli` / hot-reload via `cargo watch` |
| `just audit` / `just deny` / `just sbom` | Security: cargo-audit / cargo-deny / cargo-cyclonedx |
| `just pre-release` | Full gate before tag: check + audit + deny + build-release + sbom |
| `just update` / `just outdated` | Update Cargo.lock / show outdated deps |
| `just docs` | `cargo doc --workspace --no-deps --open` |
| `just clean` | `cargo clean` |

## Docker

Single-service deployment: `myhealth-europe` as a Rust binary with embedded SQLCipher. No separate containers for DB/cache/queue/proxy.

| Command | Purpose |
|---------|---------|
| `docker compose up` | Dev mode — bind-mount + `cargo-watch` via the `development` stage |
| `docker compose build` | Build production image (`debian:bookworm-slim`, non-root 1001:1001) |
| `docker compose -f compose.yml -f compose.production.yml up -d` | Hardened production: read_only + cap_drop ALL + tmpfs + 127.0.0.1 bind |
| `docker compose logs -f app` | Tail JSON logs |
| `docker compose down -v` | Stop + delete the `myhealth_data` volume (data loss!) |

**Volumes:**
- `myhealth_data` → `/var/lib/myhealth` (SQLCipher store, encrypted-at-rest)
- `myhealth_logs` → `/var/log/myhealth` (structured JSON logs, no PHI)
- `cargo_target`, `cargo_registry` (dev only — warm cargo cache)

**Production hardening** (compose.production.yml):
- `read_only: true`, `cap_drop: ALL` (with `cap_add: NET_BIND_SERVICE` for an optional <1024 port)
- `user: 1001:1001`, `tmpfs: /tmp:noexec,nosuid,size=50m`
- Resource limits: `cpus: 1.0`, `memory: 512M`, `pids: 100`
- Bind: `127.0.0.1:7777` — the user explicitly enables external access via their own reverse proxy
- Log rotation: 20MB × 5 files
- `pull_policy: always` from the registry — no rebuild on the host

## MCP servers (from `.mcp.json`)

| Server | Purpose |
|--------|---------|
| `github` | GitHub API (requires `GITHUB_TOKEN` env var) |
| `filesystem` | Extended filesystem operations within the project |
| `postgres` | Postgres MCP server (requires `DATABASE_URL` env var) — for future integration tests |
| `chromeDevtools` | Chrome DevTools for UI testing |
| `playwright` | Playwright for browser automation |

## Rules for agents

- **Artifact language:** English (`language.artifacts: en`). Technical terms (Rust, FHIR, OAuth, MCP, SQLite, axum, rmcp, …) stay in their original form, not transliterated.
- **Communication language:** English (`language.ui: en`).
- **Git workflow:** stay on the current branch (`git.create_branches: false`); base branch — `main`.
- **Decompose composite shell commands.** Always split combined commands into sequential calls:
  - ❌ Wrong: `git checkout main && git pull`
  - ✅ Right: first `git checkout main`, then `git pull origin main`
- **Pre-implementation phase.** Do not create source code (`crates/*`, `Cargo.toml`, `src/*`) — implementation begins only after the MoU with NLnet is signed (Q3 2026). Until then, only documentation and AI Factory artifacts may change.
- **PHI-handling principles:** no code example may contain real or plausible PHI. Use synthetic FHIR fixtures (CC0).
- **No phone-home invariant:** do not add dependencies that make outbound network calls without an explicit user-initiated trigger.
- **Documentation-first.** Any architectural decision change → ADR in `docs/adr/` BEFORE the code change.
