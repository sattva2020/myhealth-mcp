# Base rules for the MyHealth-Europe project

> Project conventions for all AI agents. There is no source code yet (pre-implementation phase),
> so the rules below are plan-based conventions derived from docs/ that become load-bearing once M1 starts.
> Once real Rust code lands, this file is refined via `/aif-evolve`.

## Naming

| Entity | Convention | Example |
|--------|------------|---------|
| Crate / module | `snake_case` | `myhealth_core`, `fhir_adapter_ua` |
| `.rs` files | `snake_case.rs` | `consent_gateway.rs`, `audit_log.rs` |
| Structs / enums / traits | `PascalCase` | `ConsentToken`, `FhirResource`, `AuditEvent` |
| Functions / methods / variables | `snake_case` | `validate_token`, `get_observations` |
| Constants | `SCREAMING_SNAKE_CASE` | `DEFAULT_TOKEN_TTL_SECONDS` |
| MCP tools | `snake_case`, with `:` for namespaces | `get_observations`, `search_records` |
| OAuth scopes | `read:<resource>:<filter>` | `read:observations:lab`, `read:medications:active` |
| FHIR resource types | `PascalCase` (as in the FHIR R4 spec) | `Observation`, `MedicationStatement` |
| Documents | `NN-kebab-case.md` (with a number) | `01-business-requirements.md` |
| ADR | `docs/adr/NNNN-kebab-case.md` | `docs/adr/0009-encryption-at-rest.md` |

## Code structure (planned)

A workspace with a multi-crate layout:

```
myhealth-europe/
├── Cargo.toml                   # workspace root
├── crates/
│   ├── myhealth-core/           # SDK / shared types (FHIR models, errors)
│   ├── myhealth-store/          # SQLite + SQLCipher + AES-GCM encryption
│   ├── myhealth-mcp/            # MCP server (rmcp-based, stdio + SSE)
│   ├── myhealth-consent/        # OAuth 2.1 Consent Gateway
│   ├── myhealth-audit/          # Append-only audit log
│   ├── myhealth-ui/             # axum + htmx UI backend
│   ├── myhealth-cli/            # CLI (myhealth import/backup/restore/...)
│   └── adapters/
│       ├── adapter-ua-nszu/     # eHealth UA (NSZU-FHIR)
│       ├── adapter-ee-digilugu/ # Estonia Digilugu (CDA→FHIR)
│       ├── adapter-apple/       # Apple Health (XML→FHIR)
│       └── adapter-generic-r4/  # Generic FHIR R4
├── installers/                  # tauri-bundler configs (.msi/.dmg/.AppImage/.deb)
├── docker/                      # Dockerfile, compose.yml
├── docs/                        # Documentation (BRD/PRD/architecture/threat-model/ADRs)
└── tests/                       # Integration + property-based + benchmarks
```

Hard dependency boundaries (deny cycles):
- `adapters/*` → `myhealth-core` (only)
- `myhealth-store` → `myhealth-core`
- `myhealth-mcp` → `myhealth-store`, `myhealth-consent`, `myhealth-audit`, `myhealth-core`
- `myhealth-consent` → `myhealth-audit`, `myhealth-core`
- `myhealth-ui` → all crates
- `myhealth-cli` → all crates except `myhealth-ui`

## Error handling

- **Crate-local error types via `thiserror`** — every crate has its own `Error` enum, no `Box<dyn Error>` in the public API.
- **`anyhow::Result` only in `myhealth-cli`** — binaries may use `anyhow` for context; library crates may not.
- **No `.unwrap()` / `.expect()` in production code paths.** Allowed only in tests and in `main.rs` for panic-on-startup config errors.
- **PHI never lands in `Display`/`Debug` of error types.** Errors carry identifiers (record id, resource type), not contents.
- **`Result<T, E>` first.** `panic!`/`unreachable!` only with an explicit safety comment alongside.

## Logging and telemetry

- **`tracing` for structured logs** with JSON output via `tracing-subscriber`.
- **Log levels:** `error` (needs attention), `warn` (off-nominal but continuing), `info` (state transitions), `debug` (developer), `trace` (verbose).
- **No PHI in logs.** Instead of `tracing::info!("imported {bundle:?}")`, use `tracing::info!(record_count = bundle.entries.len(), source = %source_name, "import completed")`.
- **No telemetry by default.** `telemetry=disabled` in the default config (NFR-S5).
- **Audit events (grant/deny/revoke/read) — a separate append-only channel**, not the regular `tracing` log.

## Encryption and secrets handling

- **`secrecy::SecretString` / `secrecy::SecretVec` for all keys and passphrases.** Never `String` for secrets.
- **`zeroize` for structs holding sensitive data** — `#[derive(ZeroizeOnDrop)]` where possible.
- **Argon2id KDF** with memory ≥64 MB, iterations ≥3, parallelism ≥4 (FR-2.2).
- **AES-256-GCM with random nonce** for application-layer column encryption.
- **SQLCipher via `rusqlite` feature `bundled-sqlcipher`** for the full-DB encryption baseline.
- **No hardcoded key / passphrase / token** in code, tests, or fixtures. Test keys are generated per test.
- **CI secret scanning** via Trufflehog/Gitleaks on pre-commit and in GitHub Actions.

## Testing

- **`cargo test` for unit + integration.**
- **`proptest` for property-based testing** of FHIR parsers, OAuth flows, encryption roundtrips.
- **`criterion` for benchmarks** — `cargo bench` (NFR-P1: p99 <200 ms).
- **Integration tests:** the top-level `tests/` directory, with a real SQLCipher store (no mocks for encryption).
- **Coverage targets:** ≥80% lines, ≥70% branches (NFR-M1). Tarpaulin or grcov in CI.
- **Raspberry Pi 4 smoke test in CI** — `cross`-build for `aarch64-unknown-linux-gnu` + QEMU run.

## Linting and formatting

- **`rustfmt` is mandatory before commit** (pre-commit hook + CI check).
- **`clippy` with `-D warnings` on main** (NFR-M2). `#[allow(...)]` is allowed only with a justification comment.
- **`cargo-audit` in CI** — fails on a new CVE.
- **`cargo-deny` in CI** — policy for licenses, sources, advisories, banned crates.

## Code documentation

- **100% of the public API has doc comments (`///`)** (NFR-M3). Internal `fn`/`struct` items only as needed.
- **`#![deny(missing_docs)]` at crate level** for library crates.
- **Doctests are mandatory for non-trivial public functions** — usage example in the docstring.
- **ADRs for all non-trivial choices** in `docs/adr/NNNN-kebab-case.md`.

## Architectural invariants (enforced at the code level)

- **No outbound network from the server process** beyond explicit user-initiated calls. CI has network egress monitoring.
- **PHI never leaves the boundary without consent token validation.** Every MCP tool handler starts with `consent.verify(token, scope)?`.
- **Append-only audit log** — `INSERT`-only, no `UPDATE`/`DELETE` on the audit table.
- **Resources are read-only in phase 1.** Write-back tools are out of scope (FR-3.8).
- **No PHI in unencrypted backup files.** `myhealth backup` produces only an encrypted blob.

## Git / commits

- **Conventional Commits** (`/aif-commit` to generate messages).
- **Branches:** `feature/` for new features, `fix/` for bug fixes. The current `git.create_branches: false` setting → `/aif-plan full` stays on the current branch.
- **Base branch:** `main`.
- **No `--no-verify` / `--no-gpg-sign`** without explicit permission.
- **Signed releases** via `cosign` (NFR-S4).

## i18n / Language rules

- **Documentation:** English (current, after the 2026-05-15 translation pass), with possible localisations to UA/EE/DE/PL in v1.0 (FR-5.9).
- **Technical terms (Rust, FHIR, OAuth, MCP, SQLite, etc.) — keep their original form**, do not transliterate.
- **UI strings:** via `fluent` or `rust-i18n` (to be decided in M6); never hard-coded in components.
- **Error messages for end users:** localised; for developers / logs — English.

## Dependencies and supply chain

- **Prefer crates with audit history** (Signal, Bitwarden, Tokio ecosystem).
- **New dependencies require an ADR review** if they land in `[dependencies]` of a primary crate (not dev/build).
- **`cargo-cyclonedx` for SBOM** with every release in CycloneDX format.
- **Dependabot** for security updates.
- **SLSA Level 2** as the target for the release pipeline.
