# 02 — Product Requirements Document (PRD)

**Document:** MyHealth-Europe — product requirements
**Version:** 0.1
**Date:** 2026-05-12
**Owner:** Ruslan Hryban
**Linked to grant draft:** milestones M1-M9 in [`../../NGI-CommonsFund-13-DRAFT-2026-05-08.md`](../../NGI-CommonsFund-13-DRAFT-2026-05-08.md), section 5.

---

## TL;DR (for the review committee)

The product consists of six functional building blocks: (1) FHIR importers from three sources, (2) an encrypted local store, (3) an MCP server with a tools surface for AI agents, (4) an OAuth 2.1 consent gateway with time-bound tokens, (5) a reference UI client for self-hosted use, (6) a reference cross-border navigation agent. Each block is tied to a specific milestone in the grant draft with acceptance criteria.

Key non-functional requirements: privacy-by-architecture (no project backend), self-hostability (Docker plus native binary), accessibility (WCAG 2.1 AA for the UI), low resource footprint (runs on a Raspberry Pi 4), and an untrusted-client model (we assume the AI agent may be malicious).

---

## 1. Product overview

### 1.1. What it is

An open-source software bundle that an EU citizen installs on their own device. It consists of a server process (the MCP server), a local-only web UI, a set of CLI commands for import/export, and a reference AI agent that demonstrates the end-to-end pattern.

### 1.2. What it looks like to the user

```
$ docker compose up -d myhealth-europe
$ open http://localhost:7777
[UI: "Welcome. Step 1: import your data"]
$ myhealth import digilugu ~/Downloads/digilugu-export.json
Imported 245 records from Estonia Digilugu.
$ open claude://
[in Claude Desktop:] "Summarise my lab results for the last 6 months"
[Claude:] "Requesting permission to read Observation with category=lab..."
[UI shows a prompt:] "Approve? [Yes 1h] [Yes 24h] [No]"
[The user clicks Yes 1h]
[Claude receives the data, produces the summary]
```

### 1.3. Who the typical user is

- **Persona A — "Anna, expat in Berlin":** 34 years old, IT analyst, moved from Kyiv in 2023. Has records in eHealth UA (older history) and German ePA (newer ones). Wants an AI assistant that can answer questions like "when did I get my whooping-cough vaccination?" (the answer is in the Ukrainian records) in English or German.
- **Persona B — "Johann, retiree from Munich":** 71 years old, spends winters in Alicante and is treated there by a local GP. Wants AI to help compare his German and Spanish prescriptions (potential interactions, duplicates).
- **Persona C — "Olga, nurse from Estonia with a chronic condition":** 42 years old, an active Digilugu user, interested in local LLMs (Llama on her own laptop). Wants to query a private agent without sending data to a cloud provider.

---

## 2. Functional requirements (FR)

Numbering: `FR-X.Y` where X is the module and Y is the specific requirement.

### 2.1. Module 1: FHIR importers

| ID | Requirement | Acceptance criteria | Milestone |
|----|-------------|---------------------|-----------|
| FR-1.1 | Import a FHIR R4 bundle from a file | CLI command `myhealth import <source> <path>`; UI upload form; JSON parsing; validation against the R4 schema | M2 |
| FR-1.2 | Adapter for eHealth Ukraine | Accepts NSZU-FHIR exports, normalises NSZU extensions, converts dates and language tagging | M2 |
| FR-1.3 | Adapter for Estonia Digilugu | Accepts a Digilugu FHIR bundle, handles CDA→FHIR for legacy records | M2 |
| FR-1.4 | Adapter for Apple Health | Accepts an Apple Health Export ZIP, converts XML into FHIR Observation/Condition | M2 |
| FR-1.5 | Idempotent re-import | Re-importing the same file yields `count_new=0`, `count_existing=N`, with no duplicates | M2 |
| FR-1.6 | Import summary | After an import — a report: counts by resource type, date range, validation errors detected | M2 |
| FR-1.7 | Partial recovery | If part of a bundle is invalid, valid records are imported and invalid ones go into quarantine with a reason | M3 |

### 2.2. Module 2: Local store

| ID | Requirement | Acceptance criteria | Milestone |
|----|-------------|---------------------|-----------|
| FR-2.1 | Storage in SQLite | SQLite DB file with hybrid encryption-at-rest: SQLCipher full-DB (baseline) plus application-layer AES-GCM column-level encryption for the most sensitive PHI fields (defense-in-depth, GDPR erasure via per-record key rotation). ADR-009 in `06-architecture.md`. | M3 |
| FR-2.2 | Encryption key derived from a user passphrase | Argon2id (≥64MB memory, ≥3 iterations); the key is never written to disk; reset = data loss | M3 |
| FR-2.3 | Query API at the FHIR resource level | Internal API: `get_observations(filter)`, `get_conditions(filter)`, `get_medications(filter)`, etc. | M3 |
| FR-2.4 | p99 latency < 200ms on a 1000-record dataset | Benchmark suite in CI | M3 |
| FR-2.5 | Backup / restore | `myhealth backup --out file.enc` creates an encrypted backup; `restore` brings it back | M9 |
| FR-2.6 | Soft delete plus hard delete | Deletion is initially soft (recoverable for 30 days), then hard | M9 |

### 2.3. Module 3: MCP server

| ID | Requirement | Acceptance criteria | Milestone |
|----|-------------|---------------------|-----------|
| FR-3.1 | Compatibility with MCP spec v0.6+ | Passes the MCP Inspector test suite | M4 |
| FR-3.2 | Transport: stdio | The standard MCP stdio transport works with Claude Desktop | M4 |
| FR-3.3 | Transport: SSE/HTTP | For remote-client scenarios (with the user's consent) | M4 |
| FR-3.4 | Tools: read-only surface | `get_observations`, `get_conditions`, `get_medications`, `get_allergies`, `get_immunizations`, `get_encounters`, `get_diagnostic_reports`, `search_records` | M4 |
| FR-3.5 | Tool: `get_health_summary` | Structured overview without raw PHI (count by category, date ranges) — for agents that want to choose scope intelligently | M4 |
| FR-3.6 | Resources: published examples | `health://schema/observation`, `health://examples/sample` — sample resources for agent learning | M4 |
| FR-3.7 | Prompts: reference prompts | Pre-built prompts for typical queries (summary, medication reconciliation, lab trend) | M4 |
| FR-3.8 | Write-back operations | **Not in phase 1.** Out of scope until phase 2 | — |

### 2.4. Module 4: Consent gateway

| ID | Requirement | Acceptance criteria | Milestone |
|----|-------------|---------------------|-----------|
| FR-4.1 | OAuth 2.1 token issuance | Standard OAuth 2.1 flow for the AI agent; refresh tokens; PKCE | M5 |
| FR-4.2 | Scope-by-resource-type | Scope strings: `read:observations:lab`, `read:medications:active`, etc. Granularity by category | M5 |
| FR-4.3 | Time-bound tokens | TTL presets: 5 min, 1h, 24h, 7d, persistent (with warning); 30-day maximum | M5 |
| FR-4.4 | One-click revoke | UI sessions list with a revoke button; programmatic revoke endpoint | M5 |
| FR-4.5 | Per-resource-type confirmation | If the agent requests a scope that covers sensitive categories (psych, sexual, genetic), an additional confirmation step is required | M5 |
| FR-4.6 | Audit-log entry | Every grant/deny/revoke/read is a separate event in an append-only log | M5 |
| FR-4.7 | Threat model documented | STRIDE for the consent gateway; `08-threat-model.md` updated | M5 |
| FR-4.8 | Pen-test passed | External penetration test of the consent flow before M8 | M8 |

### 2.5. Module 5: Reference UI client

| ID | Requirement | Acceptance criteria | Milestone |
|----|-------------|---------------------|-----------|
| FR-5.1 | Web UI on localhost:7777 (default) | Works offline; no external CDN dependencies; bundled assets | M6 |
| FR-5.2 | Setup wizard | First run — passphrase, backup story, importer choice | M6 |
| FR-5.3 | Import workflow | Drag-and-drop file → adapter detection → import progress → summary | M6 |
| FR-5.4 | Records browser | Browse records by category, date, source; full-text search | M6 |
| FR-5.5 | Sessions / consent management | Active sessions list, history, revoke | M6 |
| FR-5.6 | Audit-log viewer | Filterable view of audit events; export as CSV/JSON | M6 |
| FR-5.7 | Settings | Theme, interface language (UA/EN/EE/DE/PL), backup config | M6 |
| FR-5.8 | WCAG 2.1 AA | Automated (axe-core) plus manual screen-reader test pass | M6 |
| FR-5.9 | i18n: 5 languages at release | UA, EN, EE, DE, PL in v1.0 | M9 |
| FR-5.10 | User testing (n≥10) | Usability test before M7, feedback integrated | M6 |

### 2.6. Module 6: Reference cross-border navigation agent

| ID | Requirement | Acceptance criteria | Milestone |
|----|-------------|---------------------|-----------|
| FR-6.1 | UA-EE pilot flow | End-to-end: import UA + EE → the agent answers questions about "continuity of prescriptions" | M7 |
| FR-6.2 | Prescription review | Finds active prescriptions in both systems, compares them, flags possible interactions (using an internal library or an EU-published drug-interaction DB) | M7 |
| FR-6.3 | Language bridge | UA query → UA answer; EN query → EN answer; with record-level translation only where needed | M7 |
| FR-6.4 | Document preparation for a new family doctor | A structured PDF/HTML with key history, prescriptions, allergies, in the destination country's language | M7 |
| FR-6.5 | Model transparency | The UI shows which model is used, where it lives, and what was sent | M7 |
| FR-6.6 | Deployment via HealBot.pro | A reference deployment is live in HealBot.pro infrastructure with real user testing | M7 |

### 2.7. Module 7: Documentation and replication kit

| ID | Requirement | Acceptance criteria | Milestone |
|----|-------------|---------------------|-----------|
| FR-7.1 | README with a 5-minute quickstart | From `git clone` to a working import in <5 minutes on a typical laptop | M9 |
| FR-7.2 | Deployment guide | Docker compose, native binary, Raspberry Pi, NAS deployment | M9 |
| FR-7.3 | Adapter development guide | Guide for writing a new FHIR adapter (example: "how to add your own country") | M9 |
| FR-7.4 | API reference | OpenAPI plus an MCP-tools reference with examples | M9 |
| FR-7.5 | Replication kit | Standalone bundle with sample data, deployment config, demo scenarios, branding placeholders | M9 |
| FR-7.6 | Security baseline doc | Threat model plus audit findings plus remediation history, all public | M9 |

---

## 3. Non-functional requirements (NFR)

### 3.1. Security & Privacy

| ID | Requirement | How we verify |
|----|-------------|---------------|
| NFR-S1 | Encryption-at-rest for all PHI | DB-file inspection: no plaintext PHI |
| NFR-S2 | Encryption-in-transit for UI ↔ server | TLS for non-localhost; localhost may run plaintext |
| NFR-S3 | No phone-home | Network-egress monitoring in CI: no outbound connections from the server process other than explicitly user-initiated ones |
| NFR-S4 | Supply chain | SBOM with each release; signed releases (cosign); dependabot |
| NFR-S5 | No telemetry by default | Default config: telemetry=disabled |
| NFR-S6 | OWASP ASVS L2 baseline | Self-assessment plus external audit |
| NFR-S7 | Secret scanning in CI | Trufflehog/Gitleaks pre-commit and CI |

### 3.2. Performance

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-P1 | FHIR query p99 latency | <200ms on a 10K-record dataset |
| NFR-P2 | Import 1000 records | <30s |
| NFR-P3 | Memory footprint at idle | <100MB RSS |
| NFR-P4 | Disk footprint without data | <100MB |
| NFR-P5 | Cold start | <3s |
| NFR-P6 | Runs on Raspberry Pi 4 (2GB) | Smoke test in CI |

### 3.3. Reliability

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-R1 | Atomic write to the store | Crash-safe: kill -9 during an import does not leave a corrupt store |
| NFR-R2 | Backup integrity | Restore-test in CI: backup → restore → assert equal |
| NFR-R3 | Version migrations | Schema changes have reversible migrations |

### 3.4. Usability

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-U1 | WCAG 2.1 AA | axe-core score = 0 errors; manual test pass |
| NFR-U2 | i18n | UA, EN, EE, DE, PL in v1.0 |
| NFR-U3 | Onboarding time | New user: from install to first import in <15 minutes |

### 3.5. Operability

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-O1 | Single-container deployment | `docker run myhealth-europe:latest` is enough |
| NFR-O2 | Native binary | Linux/macOS/Windows x86_64 plus ARM64 |
| NFR-O3 | Logging | Structured JSON logs; configurable level; no PHI in logs |
| NFR-O4 | Health-check endpoint | `/healthz` without auth for liveness |
| NFR-O5 | Graceful shutdown | SIGTERM → flush audit → finish requests → exit |

### 3.6. Maintainability

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-M1 | Test coverage | Lines: ≥80%; branches: ≥70% |
| NFR-M2 | Lint clean | 0 lint warnings on main |
| NFR-M3 | Documented public API | 100% of public functions/classes have doc comments |
| NFR-M4 | Architecture decision records | ADRs for every non-trivial choice in `docs/adr/` |

---

## 4. Dependencies between modules (implementation order)

```
M1 (repo + CI)
   │
   ▼
M2 (FHIR importers) ─────────► M3 (local store)
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
                                                     M8 (security audit)
                                                          │
                                                          ▼
                                                     M9 (docs, replication, v1.0)
```

This is the critical path — a delay in any block shifts the entire branch.

---

## 5. Acceptance criteria for the v1.0 release

The v1.0 release (M9) ships IF:

1. All FRs from phase 1 (FR-1.* through FR-7.*) are implemented and covered by tests.
2. All medium+ findings from the security audit are closed.
3. p99 latency < 200ms is confirmed by benchmark.
4. The reference agent demonstrates an end-to-end UA-EE flow on live (or realistic test) infrastructure.
5. ≥3 downstream adopters have confirmed interest in writing (deployment is not required).
6. The documentation passes the test: a new developer can complete the quickstart and write their own adapter in 1 day.

---

## 6. Out-of-scope (explicitly NOT in phase 1)

- Write-back to national e-health systems.
- Live FHIR API connectors (because of per-provider OAuth and operational complexity).
- Native mobile clients (web UI only in phase 1).
- Adapters beyond the 3 planned (PL, DE, FR — phase 2).
- Cluster / multi-user deployments.
- Hosted SaaS deployment (downstream may do this).
- Clinical models or integrated LLMs (this is the work of the user's agent).

---

*See: [01-business-requirements.md](01-business-requirements.md) for business context; [06-architecture.md](06-architecture.md) for component decomposition; [05-tech-stack.md](05-tech-stack.md) for tech-stack recommendations.*
