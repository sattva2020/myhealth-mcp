# LICENSES/

Canonical text of every open-source license referenced anywhere in this repository, one file per SPDX identifier. Required by [REUSE Specification 3.0](https://reuse.software/spec/).

| File | SPDX identifier | Applies to | Canonical source |
|---|---|---|---|
| `Apache-2.0.txt` | `Apache-2.0` | MCP server core, FHIR adapters, OAuth 2.1 consent gateway, local store, audit log, FHIR types, top-level binary, future reference UI client, build scripts, CI configuration | [apache.org](https://www.apache.org/licenses/LICENSE-2.0.txt) |
| `AGPL-3.0-or-later.txt` | `AGPL-3.0-or-later` | Future `crates/reference-agent/` — the cross-border navigation demonstration | [gnu.org](https://www.gnu.org/licenses/agpl-3.0.txt) |
| `CC-BY-SA-4.0.txt` | `CC-BY-SA-4.0` | `docs/`, `README.md`, `LICENSING.md`, design documents | [creativecommons.org](https://creativecommons.org/licenses/by-sa/4.0/legalcode.txt) |
| `CC0-1.0.txt` | `CC0-1.0` | Future `testdata/` — synthetic FHIR datasets | [creativecommons.org](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt) |

The root `LICENSE` file at the repository root is a copy of `Apache-2.0.txt` and is kept there for compatibility with tools and people who look at the root before reading anything else. The authoritative answer for any given file is the SPDX identifier in that file's header, resolved against this directory.

## Rules for editing this directory

- Do **not** edit existing license texts. They must remain byte-for-byte identical to the canonical source. Tools (REUSE lint, GitHub license detection, SPDX scanners) verify this.
- Adding a new license: create a new file named exactly `<SPDX-identifier>.txt`, paste the canonical text from the SPDX license list, and add a row to the table above. Then update the table in [`../LICENSING.md`](../LICENSING.md) and the matrix in [`../docs/07-licensing-strategy.md`](../docs/07-licensing-strategy.md).
- Removing a license: only after every file that referenced it has been removed or relicensed. Always run `reuse lint` after the removal.

## Verification

```bash
# REUSE compliance check (install: pip install reuse)
reuse lint

# SPDX license detection (install: cargo install spdx-toolset)
spdx-toolset detect crates/

# Cargo-deny license enforcement (driven by deny.toml)
cargo deny check licenses
```

CI runs these checks; PRs that introduce a non-allowlisted license or a file without an SPDX header should fail before merge.

## Why per-component licensing

Project rationale lives in [`../LICENSING.md`](../LICENSING.md) (downstream-facing summary) and [`../docs/07-licensing-strategy.md`](../docs/07-licensing-strategy.md) (full design rationale). The short version: permissive on infrastructure components for maximum adoption by national e-health systems and integrators; copyleft on the deployable reference agent to keep the demonstration in the commons; share-alike on documentation; zero-friction on synthetic test data.
