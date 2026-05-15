# MyHealth-Europe — Roadmap

> Open-source MCP server for citizen-controlled health data in the EU.
> Pre-implementation phase. Implementation begins after the MoU with NLnet is signed (expected Q3 2026).
> Requirement details: [.ai-factory/DESCRIPTION.md](DESCRIPTION.md), [docs/02-prd.md](../docs/02-prd.md). Architecture: [.ai-factory/ARCHITECTURE.md](ARCHITECTURE.md).

## Milestones

- [ ] **M1 — Repository scaffolding + CI** — Cargo workspace (`myhealth-core`, `myhealth-store`, `myhealth-mcp`, `myhealth-consent`, `myhealth-audit`, `myhealth-ui`, `myhealth-cli`, `crates/adapters/*`), `rust-toolchain.toml` (1.80+), GitHub Actions matrix (Linux/macOS/Windows × x86_64/aarch64) with clippy/fmt/test/audit/deny, Raspberry Pi 4 smoke test via `cross`+QEMU, `cargo-cyclonedx` SBOM generation, cosign-signed releases. Acceptance: `cargo test --workspace` green on all platforms + first signed pre-release tag with SBOM.

- [ ] **M2 — FHIR importers (UA / EE / Apple / generic R4)** — implementation of the `FhirImporter` trait for 4 sources (FR-1.1—1.6): `adapter-ua-nszu` (NSZU-FHIR + extensions), `adapter-ee-digilugu` (CDA→FHIR via safe XML), `adapter-apple` (HK XML→FHIR mapping table), `adapter-generic-r4`. Streaming parser, idempotent re-import (FR-1.5), `ImportSummary` without PHI, property-based + fuzz tests. Acceptance: all 4 adapters pass synthetic + real-world (anonymised) bundle suites; CLI `myhealth import <source> <path>` working.

- [ ] **M3 — Local Store + encryption** — `myhealth-store` with SQLCipher full-DB baseline + application-layer AES-GCM column-level on the most sensitive PHI fields (free-text notes, mental health, diagnostic narratives) — ADR-009 (FR-2.1, 2.2). Argon2id KDF (≥64 MB, ≥3 iter), `secrecy`+`zeroize` for keys. Query API per-resource type (FR-2.3), per-record HMAC-MAC integrity check, partial recovery + quarantine (FR-1.7), atomic writes (NFR-R1). Acceptance: bench-suite shows p99 <200 ms on 10K records (NFR-P1), `kill -9` during import does not corrupt the store, integrity check on read working.

- [ ] **M4 — MCP server + tools** — `myhealth-mcp` on the official `rmcp` crate, MCP spec v0.6+ compliance (MCP Inspector test suite in CI). Read-only tools (FR-3.4): `get_observations`, `get_conditions`, `get_medications`, `get_allergies`, `get_immunizations`, `get_encounters`, `get_diagnostic_reports`, `search_records`, `get_health_summary`. Resources (`health://schema/*`, `health://examples/*`) and reference prompts (`summary` / `medication-reconciliation` / `lab-trend`). Transports: `stdio` default, `SSE/HTTP` opt-in with TLS+OAuth. Acceptance: Claude Desktop connects via stdio and successfully invokes all read-only tools on the test dataset.

- [ ] **M5 — Consent Gateway (OAuth 2.1)** — `myhealth-consent` with PKCE flow (FR-4.1), scope-by-resource-type granularity (FR-4.2), time-bound tokens 5 min / 1 h / 24 h / 7 d / 30 d max (FR-4.3), per-resource-type confirmation for sensitive categories psych/sexual/genetic (FR-4.5), one-click revoke (FR-4.4), append-only audit log with HMAC chain (FR-4.6). Defense-in-depth: scope check in the gateway AND in the MCP tool handler (T-M3). Threat model updated (FR-4.7). Acceptance: malicious-agent scenario (broad scope request) behaves as described in `docs/08-threat-model.md` scenario A; all STRIDE T-C* and T-M* threats have implemented mitigations.

- [ ] **M6 — Reference UI client** — `myhealth-ui` on `axum` + htmx (server-driven MPA), local-only `localhost:7777`, no external CDN (FR-5.1). Setup wizard (FR-5.2 — passphrase with zxcvbn ≥3, min 12 chars), import workflow (FR-5.3), records browser with categories/date/source/text-search (FR-5.4), sessions/consent management (FR-5.5), audit-log viewer + CSV/JSON export (FR-5.6), settings (theme, language UA/EN/EE/DE/PL — FR-5.7), WCAG 2.1 AA via axe-core = 0 errors + manual screen-reader (FR-5.8, NFR-U1). User testing n≥10 (FR-5.10). Acceptance: a new user from install to first import in <15 min (NFR-U3), accessibility audit passed.

- [ ] **M7 — Reference cross-border navigation agent (HealBot.pro)** — AGPL 3.0 agent, end-to-end UA-EE pilot flow (FR-6.1): import UA + EE → "continuity of prescriptions" → interaction detection (internal library or EU drug interaction DB — FR-6.2) → language bridge UA↔EN with record-level translation only where needed (FR-6.3) → structured PDF/HTML for the new family doctor in the destination country (FR-6.4) → model transparency (which model, where it lives, what was sent — FR-6.5). Live deployment in HealBot.pro infrastructure with real user testing (FR-6.6). Acceptance: ≥3 cross-border sessions with volunteer users, ≥2 examples of detected drug interactions in the demo.

- [ ] **M8 — External security audit + pen-test** — focused audit on the consent gateway flow (FR-4.8), encryption-at-rest (T-S*), MCP tool boundary (T-M*), supply chain (T-B*). Auditors receive a signed binary + source + threat model. All medium+ findings closed before release v1.0. Audit findings + remediation history are published in `docs/audit-2026.md`. SBOM diff is published. Acceptance: external audit report with 0 high, ≤2 medium-open findings, all critical fixes merged, pen-test report added to the release artifacts.

- [ ] **M9 — Documentation + replication kit + v1.0 release** — README with a 5-min quickstart `git clone` → working import (FR-7.1), deployment guides Docker/native binary/Raspberry Pi/NAS (FR-7.2), adapter development guide ("how to add your country" — FR-7.3), API reference OpenAPI + MCP tools (FR-7.4), standalone replication kit (sample data + deployment config + demo scenarios + replaceable branding — FR-7.5), security baseline doc (threat model + audit findings + remediation history — FR-7.6), backup/restore (FR-2.5) + soft/hard delete (FR-2.6), i18n in 5 languages UA/EN/EE/DE/PL (FR-5.9). Acceptance: ≥3 downstream adopters confirmed interest in writing; a new developer can complete the quickstart and write their own adapter in 1 day; v1.0 signed release with full SBOM, cosign signature, SLSA Level 2 provenance.

## Completed

| Milestone | Date |
|-----------|------|
| Pre-implementation: docs (BRD/PRD/Data Flow/User Flow/Tech Stack/Architecture/Licensing/Threat Model) | 2026-05-12 |
| Pre-implementation: AI Factory project context (DESCRIPTION/ARCHITECTURE/rules + base/security/fhir/mcp areas) | 2026-05-12 |
| Pre-implementation: Build automation (justfile) + Docker setup (Dockerfile + compose × 3 + .dockerignore + .env.example) | 2026-05-12 |
| Pre-implementation: Project documentation translated to English (README, AGENTS, docs/, .ai-factory/) | 2026-05-15 |
