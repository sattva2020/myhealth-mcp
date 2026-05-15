# MyHealth-Europe

**Open-source Model Context Protocol server for citizen-controlled health data in the EU.**

Apache 2.0 (core) / AGPL 3.0 (reference agent). Self-hosted. Privacy-by-architecture, not privacy-by-policy.

---

## TL;DR (for the team, the grant review committee, and external readers)

Today, AI assistants in the health space live inside whoever owns your data — Apple, Google, Epic, the national e-health portal. The user cannot take **their** agent and point it at **their** records on **their** terms. MyHealth-Europe solves exactly this: it is a piece of software that every EU citizen runs at home (on a laptop, a Raspberry Pi, a home NAS, or a self-hosted VPS), imports their FHIR records from national e-health systems, and through the MCP protocol grants any AI agent scope-limited and time-bound access to specific records — with an audit log and explicit consent for every session.

The project team has, and will have, no access to a single byte of user data. This is an architectural property, not a promise in a privacy policy.

## What the project ships as open source

| Component | License | Purpose |
|-----------|---------|---------|
| MCP server core | Apache 2.0 | Heart of the system: queries, consent, audit |
| FHIR adapters (UA, EE, Apple, Google) | Apache 2.0 | Import from bulk-export files |
| OAuth 2.1 consent gateway | Apache 2.0 | User-consent flow for AI-agent requests |
| Reference UI client (web, self-hosted) | Apache 2.0 | Local web interface for management |
| Reference cross-border navigation agent (HealBot.pro) | AGPL 3.0 | Demonstration of the pattern in a real case |
| Documentation, replication kit | CC BY-SA 4.0 | Guides for self-hosting and adaptation |
| Synthetic test datasets | CC0 | Test FHIR bundles without real PHI |

## What the project does NOT do

- **Does not collect data.** No centralised storage. No API on a project server. No analytics events.
- **Does not require a cloud account.** Everything works offline-first; cloud deployment is an option, not a requirement.
- **Does not depend on a specific LLM provider.** Works with any MCP-compatible client — Claude Desktop, OpenAI agents, local Llama models, EU-hosted commercial LLMs.
- **Does not treat or give medical advice.** This is a data layer, not a clinical product. Clinical logic lives on the AI-agent side and with the user themselves.

## Project context

- **Grant draft:** [`../NGI-CommonsFund-13-DRAFT-2026-05-08.md`](../NGI-CommonsFund-13-DRAFT-2026-05-08.md) — version v0.2 of the application draft for NGI Zero Commons Fund #13 (deadline 2026-06-01, request €50,000).
- **Umbrella positioning:** MyHealth-Europe = Module #1 (Health) of the broader open-source project **CivicAI Bridge**, which the team is preparing for submission to DIGITAL-2027-AI.
- **Team:** 4 co-founders (Ruslan Hryban — Project Lead, Oleksandr Suraiev — Coordination, Dmytro Myroshnykov — BD/EU networking, Tetiana Hryban — Domain Advisor).

## Navigating docs/

Each document is two-layered: first a TL;DR (5–10 lines, for non-technical readers), then a deep dive (for developers and auditors).

| # | Document | What's inside |
|---|----------|---------------|
| 01 | [Business Requirements (BRD)](docs/01-business-requirements.md) | Problem, audience, goals, KPIs, scope, constraints |
| 02 | [Product Requirements (PRD)](docs/02-prd.md) | Functional and non-functional requirements, features by M1–M9 |
| 03 | [Data Flow](docs/03-data-flow.md) | **Most important for the review committee.** Where data comes from, how it moves, what never leaves |
| 04 | [User Flow](docs/04-user-flow.md) | User journeys: installation, import, consent, day-to-day use |
| 05 | [Tech Stack](docs/05-tech-stack.md) | Comparison of Python / TypeScript / Go / Rust — **Rust + `rmcp` locked in** |
| 06 | [Architecture](docs/06-architecture.md) | Components, trust boundaries, deployment topology |
| 07 | [Licensing Strategy](docs/07-licensing-strategy.md) | Apache 2.0 / AGPL 3.0 split, rationale, downstream guidance |
| 08 | [Threat Model](docs/08-threat-model.md) | STRIDE analysis, assumptions, countermeasures, linkage to M5/M8 |

## Current project status

**Pre-implementation, design phase.** The grant draft is in final review; this workspace describes the system before the application is submitted. Implementation begins after the MoU with NLnet is signed (expected Q3 2026).

## License

The project uses a **multi-license structure** (one SPDX identifier per component):

- **Apache 2.0** — MCP server core, FHIR adapters, OAuth consent gateway, local store, audit log, FHIR types, build/CI scripts
- **AGPL 3.0 or later** — reference cross-border navigation agent (to be added under `crates/reference-agent/`)
- **CC BY-SA 4.0** — documentation and design documents (`docs/`, this `README.md`, `LICENSING.md`)
- **CC0 1.0** — synthetic FHIR test datasets (to be added under `testdata/`)

Quick reference — [`LICENSING.md`](LICENSING.md) (downstream-facing summary). Full design rationale — [`docs/07-licensing-strategy.md`](docs/07-licensing-strategy.md). Canonical texts of all licenses live under [`LICENSES/`](LICENSES/) (REUSE Specification 3.0). Project attribution — [`NOTICE`](NOTICE).

Per-file SPDX headers in every source file are the canonical answer for that individual file. For PRs, all commits must be signed off under the [DCO](https://developercertificate.org/) (`git commit -s ...`); no CLA is used.

## Contact

Ruslan Hryban — ruslan.griban@gmail.com — `linkedin.com/in/ruslan-hryban-ai`
