# Licensing structure

MyHealth-Europe uses **per-component open-source licenses**. The license that applies to any given file is determined by the SPDX identifier in the file header. This document is the navigator; for the design rationale see [`docs/07-licensing-strategy.md`](docs/07-licensing-strategy.md).

## TL;DR — license per component

| Component | License | SPDX identifier | Where it lives |
|---|---|---|---|
| MCP server core | Apache 2.0 | `Apache-2.0` | `crates/mcp-server/` |
| FHIR import adapters | Apache 2.0 | `Apache-2.0` | `crates/adapters/` |
| OAuth 2.1 consent gateway | Apache 2.0 | `Apache-2.0` | `crates/consent-gateway/` |
| Local store (SQLCipher + AES-GCM) | Apache 2.0 | `Apache-2.0` | `crates/store/` |
| Audit log | Apache 2.0 | `Apache-2.0` | `crates/audit-log/` |
| FHIR R4 types | Apache 2.0 | `Apache-2.0` | `crates/fhir-types/` |
| Top-level binary `myhealth` | Apache 2.0 | `Apache-2.0` | `crates/myhealth/` |
| Reference UI client (web) | Apache 2.0 | `Apache-2.0` | `crates/ui-client/` *(to be added)* |
| **Reference cross-border navigation agent** | **AGPL 3.0 or later** | `AGPL-3.0-or-later` | `crates/reference-agent/` *(to be added)* |
| Build scripts, CI, infrastructure | Apache 2.0 | `Apache-2.0` | `justfile`, `Dockerfile`, `compose*.yml`, `.github/`, `scripts/` |
| Documentation, replication kit, design docs | CC BY-SA 4.0 | `CC-BY-SA-4.0` | `docs/`, `README.md`, this file |
| Synthetic FHIR test datasets | CC0 1.0 | `CC0-1.0` | `testdata/` *(to be added)* |

The root `LICENSE` file at the project root contains the **Apache License, Version 2.0** because Apache 2.0 is the dominant license across all current crates. The AGPL 3.0 component (`crates/reference-agent/`) will be added during implementation; until then, the only Apache 2.0 license text applies to the repository's source code.

## Why a split?

Short version: permissive for infrastructure adoption, copyleft for the deployable reference.

- **Apache 2.0 on infrastructure.** National e-health teams, hospital integrators, and other open-source projects must be able to adopt the MCP server, FHIR adapters, and consent gateway without copyleft friction in their stacks. Adoption is the entire point of providing a reference implementation.
- **AGPL 3.0 on the reference agent.** The cross-border navigation agent is the deployable demonstration. AGPL closes the SaaS loophole: a hosted fork of the reference must publish its source. Without that, anyone could wrap our reference in a closed SaaS and contradict the project's commons positioning.
- **CC BY-SA 4.0 on documentation.** Standard for shareable docs; ensures derivatives stay open.
- **CC0 on synthetic test data.** Zero-friction reuse for test fixtures.

This pattern follows the licensing model used by Mastodon, Nextcloud, Sentry, Standard Notes, and Open edX. NLnet's recognised-license list includes all four licenses used here. Full design rationale: [`docs/07-licensing-strategy.md`](docs/07-licensing-strategy.md).

## Per-file SPDX identifiers

Every source file carries an SPDX header that gives the canonical license for that file. Examples:

For Apache 2.0 files (most of the codebase):

```rust
// SPDX-FileCopyrightText: 2026 MyHealth-Europe contributors
// SPDX-License-Identifier: Apache-2.0
```

For AGPL 3.0 files (the reference agent, once added):

```rust
// SPDX-FileCopyrightText: 2026 MyHealth-Europe contributors
// SPDX-License-Identifier: AGPL-3.0-or-later
```

For Markdown documentation (use HTML comment so it does not render):

```markdown
<!--
SPDX-FileCopyrightText: 2026 MyHealth-Europe contributors
SPDX-License-Identifier: CC-BY-SA-4.0
-->
```

The `LICENSES/` directory at the repository root holds the full text of each license referenced in SPDX headers, in compliance with [REUSE Specification 3.0](https://reuse.software/spec/).

## Downstream — what you can and cannot do

Three common scenarios:

**You want to localise the project for your country (write a new FHIR adapter, ship a national variant).**
You are using Apache 2.0-licensed code only. You can fork, modify, ship commercially, charge for hosting, and you are not obligated to upstream your changes — though we appreciate contributions. Just keep the LICENSE and NOTICE files in your distribution and add your own copyright notices.

**You want to build a SaaS offering around the project.**
If you use only the Apache 2.0 components (server core, adapters, gateway, UI client), there are no copyleft obligations. You can build a managed hosting service, add proprietary UI on top, and monetise. If you use the reference cross-border navigation agent (AGPL 3.0) as part of that SaaS, AGPL's network-use clause applies: you must offer source for your modifications to your users.

**You want to integrate MyHealth-Europe into a hospital EHR.**
Apache 2.0 covers integration without obligation to open-source the EHR itself. AGPL is triggered only if you incorporate code from the reference agent into your own product. Building your own clinical agent on top of the MCP server core does not trigger AGPL.

For more downstream scenarios see [`docs/07-licensing-strategy.md` §6](docs/07-licensing-strategy.md).

## Contributor License Agreement

We do **not** require a Contributor License Agreement. Instead, every commit must be signed off under the [Developer Certificate of Origin](https://developercertificate.org/) (DCO):

```
git commit -s -m "..."
# produces a "Signed-off-by:" trailer
```

A pre-commit hook checks that every commit on incoming PRs is properly signed. By signing off, you assert that you have the right to submit the code under its applicable license.

DCO follows the model used by the Linux kernel, Docker, and the Cloud Native Computing Foundation. It is a one-line assertion in your commit — not a separately filed legal document.

## REUSE compliance

This project follows [REUSE Specification 3.0](https://reuse.software/spec/) for license clarity:

- All license texts referenced anywhere live in `LICENSES/` at the repository root.
- Every source file carries an SPDX header (or is covered by a `REUSE.toml` rule for binary / asset files).
- A `reuse lint` check runs in CI.

The repository's [`REUSE.toml`](REUSE.toml) declares fallback license rules for files that do not (or cannot) carry an inline SPDX header — documentation, build/config files, AI-tooling configs, and the `testdata/` directory once it is added. Inline per-file SPDX headers take precedence over `REUSE.toml` rules where both are present.

## EU-specific notes

The project is funded (pending NLnet decision) under the European Union's Next Generation Internet initiative. The license set above is selected to be compatible with EU expectations for openly funded research and development:

- **EHDS** (EU Health Data Space Regulation, in force March 2025) does not prescribe a specific licence; recommends open-source for tooling — both Apache 2.0 and AGPL 3.0 qualify.
- **EUPL 1.2** was considered as an alternative for the infrastructure components but not adopted; rationale in [`docs/07-licensing-strategy.md` §8.1](docs/07-licensing-strategy.md).
- **GDPR** obligations stay with the deployer of the software. Software licenses do not transfer or limit GDPR data-controller responsibilities.

## Questions

For licensing questions email `ruslan@griban.dev` or open an issue in the public repository once it is created. A project-specific forwarding address may be set up before the first stable release; the canonical contact remains `ruslan@griban.dev` until then.
