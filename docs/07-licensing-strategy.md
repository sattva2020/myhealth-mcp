# 07 — Licensing Strategy

**Document:** MyHealth-Europe — open-source licensing strategy
**Version:** 0.2
**Created:** 2026-05-12 · **updated:** 2026-05-14
**Owner:** Ruslan Hryban

> **v0.2 changes:** updated §2 file paths to match the actual Rust workspace structure (previously a Python placeholder); added Rust SPDX-header examples in §9.1; added §9.4 "Implementation status" with checkboxes covering what is already implemented in the repo and what remains for implementation time.

---

## TL;DR

The project uses a **split-licensing model**: the system core (MCP server, FHIR adapters, consent gateway, UI client) is licensed under **Apache 2.0** (maximum adoption, downstream commercial forks allowed); the reference cross-border navigation agent is licensed under **AGPL 3.0** (encourages open-source in adopters of the reference application); documentation and the replication kit are licensed under **CC BY-SA 4.0**; sample data is licensed under **CC0**.

The rationale: the core must be "cheap" for anyone to adopt (a national e-health authority, a hospital, a startup) — hence Apache. The reference agent is a demo, an illustration of the pattern; if someone builds their own clinical agent on top of it, we want the result to remain open — hence AGPL. This split is standard for open-commons projects and aligned with NLnet expectations.

The Apache vs. AGPL question for the core was left open in the grant draft (section 13, item 5); this document closes it in favour of the split model with a rationale.

---

## 1. Principles for choosing licenses

Each license in the project is chosen against a specific optimisation criterion.

### 1.1. For the core — priority "maximum adoption"

**Target adopters of the core:**
- National e-health agencies that want to localise or fork the project for their country.
- Commercial health-tech companies that will build a managed-hosting service on top of the core.
- Research teams that want to integrate it into their pipelines.
- Hospitals and clinics that may want a deployment in a controlled environment.
- Open-source contributors and forks.

**Constraint for all of these groups:** any copyleft (GPL, AGPL) in the core creates a legal barrier to commercial adoption. A hospital with a custom EHR would not be able to integrate it, because their EHR would become a derivative work under GPL.

**Conclusion:** the core is licensed under **Apache 2.0** (permissive, copyleft-free + patent grant).

### 1.2. For the reference agent — priority "open-source in downstream"

**Target adopters of the reference agent:**
- Developers who want to understand the pattern and build their own agent.
- Pilot deployments for specific use cases (UA-EE, UA-PL, DE-ES, ...).
- Demonstration installations at community events.

**Constraint:** we don't want anyone to take our reference cross-border navigation agent, add 10% of code on top of it, and release it as a closed commercial "cross-border health AI" product — that undermines the commons. So the agent is the same case as backend SaaS: the user interacts over the network, and without strong copyleft nothing obliges them to publish modifications.

**Conclusion:** the reference agent is licensed under **AGPL 3.0** (with its SaaS clause, i.e. the network-use trigger).

### 1.3. For documentation — priority "share-alike"

**Conclusion:** **CC BY-SA 4.0**. The standard for shareable docs in the European commons space.

### 1.4. For sample data — priority "zero friction"

**Conclusion:** **CC0**. Synthetic FHIR bundles must not carry any restrictions.

---

## 2. Component-license matrix

The paths reflect the actual structure of the project's Rust workspace (a Cargo workspace with 7+ crates in `crates/`). The canonical answer for any specific file is the SPDX identifier in that file's header; the matrix below is the "default" policy, which must agree with the headers and with [`../REUSE.toml`](../REUSE.toml).

| Component | License | SPDX identifier | Files |
|-----------|---------|-----------------|-------|
| Top-level binary (`myhealth`) | Apache 2.0 | `Apache-2.0` | `crates/myhealth/src/**/*.rs` |
| MCP server core | Apache 2.0 | `Apache-2.0` | `crates/mcp-server/src/**/*.rs` |
| FHIR adapters (UA, EE, Apple, generic R4) | Apache 2.0 | `Apache-2.0` | `crates/adapters/src/**/*.rs` |
| OAuth 2.1 consent gateway | Apache 2.0 | `Apache-2.0` | `crates/consent-gateway/src/**/*.rs` |
| Local store (SQLCipher + AES-GCM) | Apache 2.0 | `Apache-2.0` | `crates/store/src/**/*.rs` |
| Audit log | Apache 2.0 | `Apache-2.0` | `crates/audit-log/src/**/*.rs` |
| FHIR R4 types | Apache 2.0 | `Apache-2.0` | `crates/fhir-types/src/**/*.rs` |
| Reference UI client *(to be added)* | Apache 2.0 | `Apache-2.0` | `crates/ui-client/**/*` |
| Reference cross-border navigation agent *(to be added)* | GNU Affero GPL v3.0 or later | `AGPL-3.0-or-later` | `crates/reference-agent/src/**/*.rs` |
| Documentation and replication kit | CC BY-SA 4.0 | `CC-BY-SA-4.0` | `docs/**/*.md`, `README.md`, `LICENSING.md`, `RELEASING.md`, `AGENTS.md`, `NOTICE` |
| Sample / synthetic FHIR data *(to be added)* | CC0 1.0 Universal | `CC0-1.0` | `testdata/**/*`, `crates/*/tests/fixtures/**/*` |
| Build scripts, infrastructure, CI | Apache 2.0 | `Apache-2.0` | `justfile`, `Cargo.toml`, `Cargo.lock`, `Dockerfile`, `.dockerignore`, `compose*.yml`, `rust-toolchain.toml`, `clippy.toml`, `deny.toml`, `.gitignore`, `.gitattributes`, `.env.example`, `.mcp.json`, `.github/**/*`, `scripts/**/*`, `crates/*/Cargo.toml` |
| AI-agent tooling configuration | Apache 2.0 | `Apache-2.0` | `.ai-factory/**/*`, `.ai-factory.json`, `.claude/**/*`, `.codex/**/*` |

---

## 3. Rationale for the split: Apache 2.0 for the core, AGPL 3.0 for the agent

### 3.1. Why NOT full Apache 2.0

If we put EVERYTHING under Apache 2.0:
- Advantage: maximum adoption across all downstream cases.
- Drawback: someone takes our cross-border navigation agent, wraps it in a GUI, adds a "$10/month" subscription, and releases it as `MyHealthMonster.app` with no obligation whatsoever to share the code. This puts pressure on the core itself ("why are we open-sourcing if someone is monetising our agent?").

### 3.2. Why NOT full AGPL 3.0

If we put EVERYTHING under AGPL 3.0:
- Advantage: all downstream forks remain open.
- Drawback: no commercial health-tech company will touch the core. No national e-health body will be able to integrate it, because their system would be "used over the network" with the core → AGPL trigger → they would have to open up their infrastructure. This is a commons-killer for any serious deployment.

### 3.3. Why the split works

- **Core — Apache 2.0** — anyone can take it, integrate it, monetise it. This is the reference implementation of an MCP server for health data. The greater the adoption, the more the standard becomes de facto.
- **Reference agent — AGPL 3.0** — this is not a standard, it's a demo. Want your own agent — build your own. Want to fork ours — fine, but the result remains open, because it's part of the commons.

This is the same pattern used by Mastodon (AGPL for the server) + ActivityPub (open standard, permissive), Element/Matrix (Apache for libraries, AGPL for the server), Bluesky (Apache for libraries, MIT for the server — a different choice, but the same split idea).

### 3.4. Alternative: dual licensing

We are not using it. Dual licensing (Apache + commercial) is a MongoDB-style business model that requires a CLA from contributors — and a CLA significantly reduces contributor accessibility. For an FSTP-funded commons project, that complexity is unjustified.

---

## 4. Contributor License Agreement (CLA)

**We do not use a CLA.** Instead — Developer Certificate of Origin (DCO).

**Why:**
- A CLA requires legal review and registration of every contributor.
- The DCO (sign-off in the commit message: `Signed-off-by: ...`) is minimal and legally sufficient.
- The DCO is used by the Linux kernel, Docker, Git, Chromium, etc. — it is the standard in Apache 2.0-based projects.

A `DCO.md` file lives in the repository, together with a pre-commit hook that checks the sign-off.

---

## 5. Third party: dependencies

### 5.1. Acceptable inbound licenses (for dependencies):

- Apache 2.0
- BSD (2-clause, 3-clause)
- MIT
- ISC
- MPL 2.0 (file-level copyleft, OK for libraries)
- LGPL 2.1+/3.0+ (dynamic linking only)
- CC0
- Python Software Foundation License
- Unlicense

### 5.2. NOT acceptable (incompatible with Apache 2.0):

- GPL 2.0 (without classpath exception)
- GPL 3.0 (without exception)
- AGPL 3.0 (because we want to keep the core permissive)
- Custom non-OSI licenses
- "Source available" non-FOSS licenses (Elastic, Confluent, BSL)
- SSPL

### 5.3. Process

- `pip-licenses` (Python) or equivalent in CI.
- Lock file checked into the repo.
- A new-dependency PR is blocked if the license is not on the allowlist.

---

## 6. Downstream guidance

This section is for people who want to fork or integrate MyHealth-Europe.

### 6.1. Scenario: "I want to do my own country"

- Take the Apache 2.0 core, fork it.
- Write your FHIR adapter under `/adapters/your_country/`.
- Contribute the adapter upstream via PR (we encourage this).
- Or keep your own private version — Apache 2.0 does not oblige upstreaming.

### 6.2. Scenario: "I want to build a SaaS around this"

- If you use the core (Apache 2.0) — there are no obstacles. You can build managed hosting, add your own UI, monetise it.
- If you use the reference agent (AGPL) — you must disclose your modifications and provide users with a source-code link.

### 6.3. Scenario: "I want to integrate this into our hospital EHR"

- Apache 2.0 allows full integration without any obligation to open up the EHR.
- The AGPL trigger only applies if you use *our reference agent code*; if you build your own clinical tool on top of the core, AGPL does not come into play.

### 6.4. Scenario: "I want to publish a scientific paper"

- The documentation is under CC BY-SA 4.0 — cite with attribution.
- Sample data is under CC0 — nothing required.
- Preferred: a link to the project and the MoU with NLnet (for citation).

---

## 7. Trademark policy

**This section is a placeholder; it will be finalised with a lawyer at M3.**

Working version:
- "MyHealth-Europe" — a potential trademark (final decision after Q4 2026, legal consultation).
- If trademarked — then a Mozilla-style policy: free use for community versions with a no-confusion test; commercial use requires a separate license.
- The logo/branding itself is licensed under CC BY-SA 4.0.

This item is NOT a blocker for open-source licensing. Trademarks and copyright are separate.

---

## 8. EU-specific nuances

### 8.1. EUPL 1.2 — why not it

The European Union Public License is the EU-recommended choice for projects that receive EU funding. However:
- EUPL is copyleft (weaker than AGPL, but still copyleft).
- It is less popular in the global OSS ecosystem — a smaller pool of contributors.
- For an NGI-funded commons project, Apache 2.0 is precedented and accepted (the [NLnet portfolio](https://nlnet.nl/project/) contains many Apache projects).
- EUPL is a good choice for public-sector-only projects; we are broader.

If NLnet expresses a preference for EUPL — we change. Until then — Apache.

### 8.2. GDPR and licensing

A license does not exempt anyone from GDPR. Downstream adopters who handle PHI in production remain data controllers. The documentation states this explicitly (`docs/deployment/gdpr-checklist.md` — to be created at M9).

### 8.3. EHDS and licensing

EHDS does not require a specific license, but it recommends open-source for tooling. The Apache 2.0 + AGPL 3.0 split fits.

---

## 9. License headers and metadata

### 9.1. Header in every source file

**Rust** (`crates/*/src/**/*.rs`) — actual code base:
```rust
// SPDX-FileCopyrightText: 2026 MyHealth-Europe contributors
// SPDX-License-Identifier: Apache-2.0
```

For the AGPL agent (`crates/reference-agent/src/**/*.rs`):
```rust
// SPDX-FileCopyrightText: 2026 MyHealth-Europe contributors
// SPDX-License-Identifier: AGPL-3.0-or-later
```

**Markdown documentation** (`docs/**/*.md`) — an HTML comment, so that it does not render in the viewer:
```markdown
<!--
SPDX-FileCopyrightText: 2026 MyHealth-Europe contributors
SPDX-License-Identifier: CC-BY-SA-4.0
-->
```

**TOML / YAML configuration** (`Cargo.toml`, `compose.yml`, etc.) — a `#` comment at the top of the file:
```toml
# SPDX-FileCopyrightText: 2026 MyHealth-Europe contributors
# SPDX-License-Identifier: Apache-2.0
```

**Shell scripts** (`scripts/**/*.sh`, `justfile`) — after the shebang:
```bash
#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 MyHealth-Europe contributors
# SPDX-License-Identifier: Apache-2.0
```

Files that don't accept comments (binary assets, lock files, vendored data) are covered by the rules in [`../REUSE.toml`](../REUSE.toml) instead of a per-file header. This is the REUSE 3.0 fallback pattern.

**Python** (sample — in case auxiliary Python tooling is added):
```python
# SPDX-FileCopyrightText: 2026 MyHealth-Europe contributors
# SPDX-License-Identifier: Apache-2.0
```

### 9.2. Repo-level

- `LICENSE` (Apache 2.0 text in the root).
- `LICENSES/` directory with the full texts of all licenses (Apache 2.0, AGPL 3.0, CC BY-SA 4.0, CC0 1.0).
- `REUSE.toml` for REUSE.software compliance.

### 9.3. REUSE compliance

The project follows the [REUSE Specification 3.0](https://reuse.software/spec/). CI verifies it via `reuse lint`. This is the standard for transparent licensing in OSS, recommended by the FSFE and adopted by many EU-funded projects.

### 9.4. Implementation status (as of 2026-05-14)

**Closed in the repo:**

- [x] `LICENSE` in the root — the canonical Apache 2.0 text (present, unmodified — deliberately, for correct auto-detection by GitHub and SPDX scanners).
- [x] `NOTICE` in the root — project-wide attribution with the names of the 4 co-founders, multi-license breakdown, NLnet funding mention, trademark notice (Apache 2.0 best practice).
- [x] `LICENSING.md` in the root — downstream-facing summary of the multi-license structure with 3 typical scenarios (localisation, SaaS, EHR integration) and an explanation of DCO instead of CLA.
- [x] `LICENSES/` directory with the canonical texts of all 4 licenses:
  - [x] `LICENSES/Apache-2.0.txt` (a copy of `LICENSE`)
  - [x] `LICENSES/AGPL-3.0-or-later.txt` (from gnu.org)
  - [x] `LICENSES/CC-BY-SA-4.0.txt` (from creativecommons.org)
  - [x] `LICENSES/CC0-1.0.txt` (from creativecommons.org)
  - [x] `LICENSES/README.md` — the directory map, editing rules, and CI verification commands
- [x] `REUSE.toml` in the root — fallback rules for files without an inline SPDX header: docs→CC-BY-SA, build/config→Apache-2.0, testdata→CC0, `crates/reference-agent/`→AGPL-3.0-or-later (preemptive). Covers the actual structure of the Rust workspace.
- [x] §2 of this document updated to reflect the real Rust workspace paths (previously a Python placeholder).
- [x] §9.1 of this document — Rust SPDX-header examples added alongside Python.
- [x] `README.md` in the root — license section updated, with links to `LICENSING.md`, `LICENSES/`, `NOTICE`, and `docs/07`.
- [x] `Cargo.toml` workspace `license = "Apache-2.0"` — correct for all 7 current crates (all of them are infrastructure).

**Pending — until the first implementation PR (M1, ~Q3 2026):**

- [ ] **SPDX headers in every `.rs` source file** across all 7 current crates (`crates/*/src/**/*.rs`). Format — see §9.1. Work to be done after the first real population of `crates/*/src/` (currently in stub state). Owner — Project Lead. Target date — by the first implementation PR.
- [ ] **CI integration of `reuse lint`** in the GitHub Actions pipeline. Add a job to the workflow after the first implementation PR. The lint must fail if a source file is missing an SPDX header or has a license identifier not registered in `LICENSES/`. Owner — Project Lead. Target date — together with the SPDX-headers PR.
- [ ] **`cargo deny check licenses`** in CI with a [`deny.toml`](../deny.toml) allowlist (Apache-2.0, BSD-2/3, MIT, ISC, MPL-2.0, LGPL-2.1+/3.0+, CC0, PSF, Unlicense — see §5.1). Owner — Project Lead. Target date — together with REUSE lint, since it's a single workflow change.

**Pending — when `crates/reference-agent/` is created:**

- [ ] **Override the workspace license** in `crates/reference-agent/Cargo.toml`: explicitly set `license = "AGPL-3.0-or-later"` (rather than `license.workspace = true`), to override the default Apache-2.0.
- [ ] **SPDX headers with the AGPL identifier** in every `.rs` file of this crate: `SPDX-License-Identifier: AGPL-3.0-or-later`.
- [ ] **AGPL NOTICE** — a separate `crates/reference-agent/NOTICE` or a section in the root `NOTICE` describing the AGPL part with a link to `LICENSES/AGPL-3.0-or-later.txt`.
- [ ] **Update `LICENSING.md`** — remove the `*(to be added)*` marker from the reference-agent row in the table.
- [ ] **Update §2 of this document** — the same (remove `*(to be added)*`).

**Pending — when `crates/ui-client/` is created:**

- [ ] SPDX headers with the Apache-2.0 identifier (the same procedure as for the other Apache crates).
- [ ] Update §2 and `LICENSING.md` — remove the `*(to be added)*` marker.

**Pending — when `testdata/` is created:**

- [ ] CC0 SPDX headers (where possible) or coverage by the `REUSE.toml` rule (already preemptively declared).
- [ ] Update §2 and `LICENSING.md` — remove the `*(to be added)*` marker.

---

## 10. Sign-off on the strategy

This document requires confirmation:

- [ ] Hryban R. (project lead) — primary decision.
- [ ] Suraiev O. — peer review.
- [ ] Myroshnykov D. — BD aspect (commercial adoption via the permissive core).
- [ ] Tetiana Hryban — noted for the record.
- [ ] (optional) Independent OSS-license lawyer — review before v1.0.
- [ ] NLnet contact — informational notice after the MoU.

---

*See: [`../../NGI-CommonsFund-13-DRAFT-2026-05-08.md`](../../NGI-CommonsFund-13-DRAFT-2026-05-08.md) section 9 for the original license planning in the grant draft; [01-business-requirements.md](01-business-requirements.md) for business context.*
