# MyHealth-Europe — Project description

> This document is the source of truth for AI agents on WHAT (the product) and WHY (the intent).
> HOW (the implementation) lives in `ARCHITECTURE.md` and `docs/06-architecture.md`.
> Current status: **pre-implementation, design phase** (no source code yet).

## Overview

**MyHealth-Europe** — an open-source Model Context Protocol server for citizen-controlled health data in the EU. Each citizen runs the program at home (on a laptop, a Raspberry Pi, a home NAS, or a self-hosted VPS), imports their FHIR records from national e-health systems (eHealth UA, Estonia Digilugu, Apple Health, generic FHIR R4), and through the MCP protocol grants any AI agent (Claude Desktop, Ollama, OpenAI Desktop) scope-limited and time-bound access to specific records — with an audit log and explicit consent for every session.

An architectural property, not a privacy-policy promise: the project team has, and will have, no access to a single byte of user data. No centralised storage. No API on a project server. No analytics events.

## Context and positioning

- **Grant draft:** NGI Zero Commons Fund #13 (v0.2, deadline 2026-06-01, request €50,000).
- **Umbrella project:** MyHealth-Europe = Module #1 (Health) of the broader open-source project **CivicAI Bridge** (DIGITAL-2027-AI).
- **Team:** 4 co-founders — Ruslan Hryban (Project Lead), Oleksandr Suraiev (Coordination), Dmytro Myroshnykov (BD/EU networking), Tetiana Hryban (Domain Advisor).
- **Implementation:** kicks off after the MoU with NLnet is signed (expected Q3 2026).

## Key functional blocks

1. **FHIR importers** (M2) — adapters for eHealth UA (NSZU-FHIR), Estonia Digilugu (CDA→FHIR), Apple Health (XML→FHIR), generic FHIR R4 bundle. Idempotent re-import, partial recovery, summary report.
2. **Local Store** (M3) — SQLite with hybrid encryption-at-rest: SQLCipher full-DB baseline + application-layer AES-GCM column-level for the most sensitive PHI fields. Argon2id KDF derived from a user passphrase; the key is never written to disk; p99 query latency <200 ms on a 10K-record dataset.
3. **MCP server** (M4) — compatible with MCP spec v0.6+, transports stdio + SSE/HTTP, read-only tools (`get_observations`, `get_conditions`, `get_medications`, `get_allergies`, `get_immunizations`, `get_encounters`, `get_diagnostic_reports`, `search_records`, `get_health_summary`), reference resources/prompts. Write-back operations are out of scope for phase 1.
4. **Consent Gateway** (M5) — OAuth 2.1 with PKCE, scope-by-resource-type (`read:observations:lab`, `read:medications:active`, …), time-bound tokens (5 min / 1 h / 24 h / 7 d / 30 d max), per-resource-type confirmation for sensitive categories (psych, sexual, genetic), one-click revoke, append-only audit log. Pen-tested by M8.
5. **Reference UI client** (M6) — local-only web UI on `localhost:7777`, offline-first (no external CDN), Setup wizard, Records browser, Sessions/consent management, Audit-log viewer, WCAG 2.1 AA, i18n (UA/EN/EE/DE/PL in v1.0).
6. **Reference cross-border navigation agent — HealBot.pro** (M7, AGPL 3.0) — end-to-end demonstration of the UA-EE flow: continuity of prescriptions, interaction detection, language bridge, preparation of a document for a new family doctor in the destination country.
7. **Documentation and replication kit** (M9) — 5-min quickstart, deployment guide (Docker/native/RPi/NAS), adapter development guide, API reference (OpenAPI + MCP tools), synthetic test datasets (CC0), security baseline document.

## Target personas

- **Persona A — Anna, expat in Berlin (34, IT analyst)** — moved from Kyiv in 2023, holds records in eHealth UA + the German ePA, wants a cross-border AI assistant.
- **Persona B — Johann, retiree from Munich (71, low-tech)** — winters in Alicante, needs a single-binary deployment without Docker.
- **Persona C — Olha, nurse from Estonia with a chronic condition (42)** — active Digilugu user, works with a local LLM (Llama on her own laptop).

## Tech stack (locked in 2026-05-12)

| Layer | Technology | Version | Purpose |
|-------|-----------|---------|---------|
| **Toolchain** | Rust stable | 1.80+ | Primary language |
| **Async runtime** | `tokio` | latest | Concurrent agents/HTTP |
| **MCP server** | `rmcp` (official, by Anthropic) | latest | MCP protocol implementation |
| **FHIR models** | `fhirbolt` | latest R4 | Strong-typed FHIR R4 |
| **Web framework** | `axum` + `tower` middleware | latest | UI backend, OAuth endpoints |
| **HTTP runtime** | `hyper` (via `axum`/`tokio`) | latest | HTTP layer |
| **Storage** | `rusqlite` with `bundled-sqlcipher` | latest | SQLite + encryption-at-rest |
| **Encryption** | `aes-gcm` + `argon2` + optionally `chacha20poly1305` | latest | AES-256-GCM + Argon2id KDF |
| **Key management** | `secrecy` + `zeroize` | latest | Zeroising keys in memory |
| **OAuth** | `oauth2` + `jsonwebtoken` (HMAC-SHA256) | latest | Consent gateway |
| **Serialization** | `serde` + `serde_json` | latest | JSON in/out |
| **Logging** | `tracing` + `tracing-subscriber` (JSON output) | latest | Structured logs (no PHI) |
| **Frontend UI** | htmx + server-driven MPA via `axum` | — | Local-only web UI on localhost:7777 |
| **Desktop installer** | `tauri-bundler` (.msi/.dmg/.AppImage/.deb) | latest | End-user desktop installers (ADR-008) |
| **Server packaging** | Docker multi-stage + `.deb`/`.rpm` | — | Server deployments (scenarios B/C) |
| **Testing** | `cargo test` + `proptest` + `criterion` | latest | Unit + property-based + benchmarks |
| **Lint** | `clippy` (deny warnings on main) | latest | Static analysis |
| **Format** | `rustfmt` | latest | Code formatting |
| **Security scan** | `cargo-audit` + `cargo-deny` | latest | CVE check + dep policy |
| **Cross-compile** | `cargo-zigbuild` + `cross` | latest | Linux/macOS/Windows × x86_64/aarch64 |
| **Releases** | `cosign` signed (SLSA Level 2 target) | — | Supply chain integrity |
| **SBOM** | `cargo-cyclonedx` (CycloneDX format) | latest | REUSE + SBOM compliance |
| **CI** | GitHub Actions with matrix builds | — | Build, test, sign |

**Rationale for choosing Rust** (full version in `docs/05-tech-stack.md`):
- Single static binary <15 MB → core value prop "self-hosted privacy-by-architecture" for the Johann persona.
- Memory safety without GC → shorter audit report for PHI-handling code.
- Resource footprint → runs on a Raspberry Pi 4 (2 GB) with headroom.
- No phase-2 rewrite tax.
- Alignment with the privacy-focused community (Signal, Bitwarden core, AGE).

Cost of this choice: ~2–3 extra weeks of inception, a narrower FHIR ecosystem (mitigated by FHIR R4's stability), a smaller pool of contributors in year one.

## Architecture

Detailed architectural principles (crate structure, dependency rules, code examples, anti-patterns) — in [`.ai-factory/ARCHITECTURE.md`](ARCHITECTURE.md).

**Pattern:** Modular Monolith + Hexagonal (Ports & Adapters) — Cargo workspace with multi-crate layout, traits as ports in `myhealth-core`, adapter implementations in domain-specific crates and `crates/adapters/*`, composition root in `myhealth-cli/src/main.rs`.

## Architectural invariants

1. **No phone-home.** No component has outbound network access to project infrastructure.
2. **Privacy-by-architecture, not privacy-by-policy.** Architectural impossibility of collecting data, not a promise not to.
3. **Untrusted-client model.** We assume an AI agent may be malicious; every request goes through the Consent Gateway.
4. **Local-first.** UI on `localhost:7777`, MCP via stdio or SSE with consent from the user.
5. **No PHI in logs.** Structured JSON logs (`tracing`); PHI is never serialised into the log.
6. **Append-only audit log.** Every grant/deny/revoke/read is a separate event; modification-in-place is impossible.

## Non-functional requirements (key targets)

- **Performance:** p99 query latency <200 ms on 10K records; import 1000 records <30 s; idle RSS <100 MB; on-disk size with no data <100 MB; cold start <3 s; Raspberry Pi 4 (2 GB) smoke test in CI.
- **Security:** OWASP ASVS L2 baseline; SBOM with every release; signed releases (cosign); dependabot; secret scanning (Trufflehog/Gitleaks); external pen-test of the consent flow before M8.
- **Reliability:** atomic writes (crash-safe); backup integrity (restore-test in CI); reversible schema migrations.
- **Usability:** WCAG 2.1 AA (axe-core = 0 errors); onboarding <15 min.
- **Operability:** single-container deployment; native binary on Linux/macOS/Windows × x86_64/ARM64; structured JSON logs; `/healthz` without auth; graceful shutdown on SIGTERM.
- **Maintainability:** test coverage ≥80% lines / ≥70% branches; lint clean (0 warnings on main); 100% public-API doc comments; ADRs in `docs/adr/`.

## Licensing strategy

| Component | License | Rationale |
|-----------|---------|-----------|
| MCP server core, FHIR adapters, Consent Gateway, Reference UI | Apache 2.0 | Maximum downstream adoption, patent grant |
| Reference cross-border agent (HealBot.pro) | AGPL 3.0 | Force multiplier for contributor reciprocity in the agent space |
| Documentation, replication kit | CC BY-SA 4.0 | Community knowledge sharing |
| Synthetic test datasets | CC0 | Zero-friction for testing and derivative works |

Details: `docs/07-licensing-strategy.md`.

## Dependencies between milestones

```
M1 (repo + CI)
   │
   ▼
M2 (FHIR importers) ──► M3 (local store)
                            │
                            ▼
                       M4 (MCP server) ──► M5 (consent gateway)
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

## What the project does NOT do

- ❌ Does not collect data. No centralised storage.
- ❌ Does not require a cloud account. Everything runs offline-first.
- ❌ Does not depend on a specific LLM provider. Any MCP-compatible client.
- ❌ Does not treat or give medical advice. This is a data layer, not a clinical product.
- ❌ No write-back operations in phase 1 (FHIR resources are read-only).

## Further documents

- `docs/01-business-requirements.md` — BRD: problem, audience, goals, KPIs, scope, constraints.
- `docs/02-prd.md` — functional and non-functional requirements, features by M1–M9.
- `docs/03-data-flow.md` — where data comes from, how it moves, what never leaves.
- `docs/04-user-flow.md` — user journeys (installation, import, consent, day-to-day use).
- `docs/05-tech-stack.md` — full rationale for Rust + `rmcp`.
- `docs/06-architecture.md` — components, trust boundaries, deployment topology.
- `docs/07-licensing-strategy.md` — Apache 2.0 / AGPL 3.0 split.
- `docs/08-threat-model.md` — STRIDE analysis, assumptions, countermeasures.
