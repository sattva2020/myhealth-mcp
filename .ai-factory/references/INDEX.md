# References Index — Roadmap

> External knowledge sources for this project's AI agents.
> Status: **Tier 1 created** (5/5) — other tiers remain candidates for subsequent `/aif-reference <url>` invocations.
>
> Created: 2026-05-12
> Config: `paths.references = .ai-factory/references/`, `language.artifacts = uk`, `technical_terms = keep`.

## How to use this file

1. Find the relevant row in the table below.
2. Run `/aif-reference <url> [--name <slug>]` — the skill will fetch, synthesize, and save it to `.ai-factory/references/<slug>.md`.
3. Mark a checkmark in the **Status** column and enter the date in **Updated**.
4. If the source has changed — `/aif-reference --update --name <slug>`.

Sizing rule: one reference ≤ 1000 lines. If the source is larger — split it into a `.ai-factory/references/<topic>/` directory with its own INDEX.md.

## Tier 1 — critical, without which grounded answers are impossible

| Reference            | Topic                                          | Source                                                                                                              | Why critical                                                                                                | Status | Updated |
| -------------------- | ---------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- | ------ | ------- |
| [`mcp-spec.md`](mcp-spec.md)              | MCP wire protocol 2025-11-25                   | https://modelcontextprotocol.io/specification + schema.ts on GitHub                                                 | M4 core. Tool schemas, resources, prompts, transports. Without the precise specification, `rmcp` would be used blindly.   | done      | 2026-05-12 |
| [`rmcp-crate.md`](rmcp-crate.md)          | Official Rust MCP SDK                          | https://docs.rs/rmcp + https://github.com/modelcontextprotocol/rust-sdk                                             | Fresh crate, not yet in the training corpus. The API is unstable between minor versions.                    | done      | 2026-05-12 |
| [`fhir-r4-core.md`](fhir-r4-core.md)      | FHIR R4 resources (Observation, Condition, …) | https://www.hl7.org/fhir/R4/observation.html, …/condition.html, …/medicationstatement.html, …/allergyintolerance.html, …/immunization.html, …/encounter.html, …/diagnostic-report.html, …/bundle.html | 7 resources surfaced in MCP tools, plus Bundle for import. Each has cardinality rules that must not be guessed. | done      | 2026-05-12 |
| [`fhirbolt-crate.md`](fhirbolt-crate.md)  | Strongly typed FHIR R4 in Rust                | https://docs.rs/fhirbolt + https://github.com/lschmierer/fhirbolt                                                   | Niche crate, low representation. Without it, adapters would be hand-written using serde_json.               | done      | 2026-05-12 |
| [`oauth-2.1-pkce.md`](oauth-2.1-pkce.md)  | OAuth 2.1 + PKCE                              | https://datatracker.ietf.org/doc/draft-ietf-oauth-v2-1/ + https://www.rfc-editor.org/rfc/rfc7636                    | M5 Consent Gateway. Exact rules for PKCE challenge/verifier, scope encoding, time-bound tokens.             | done      | 2026-05-12 |

## Tier 2 — needed episodically, but guessing is dangerous

| Reference                | Topic                              | Source                                                                                                          | Status | Updated |
| ------------------------ | ---------------------------------- | --------------------------------------------------------------------------------------------------------------- | ------ | ------- |
| `nszu-fhir-ua.md`        | eHealth UA / NSZU-FHIR profile     | https://ehealth.gov.ua (NSZU documentation) + https://www.hl7.org/fhir/R4 (base profile on which UA overrides are built) | todo      | —       |
| `digilugu-cda-ee.md`     | Estonia Digilugu CDA→FHIR mapping  | https://www.tehik.ee/en + HL7 CDA R2 normative spec + X-Road technical docs                                     | todo      | —       |
| `apple-health-xml.md`    | Apple Health export schema         | https://developer.apple.com/documentation/healthkit + apple_health_export DTD (from a real export zip)          | todo      | —       |
| `sqlcipher.md`           | SQLCipher encryption-at-rest      | https://www.zetetic.net/sqlcipher/sqlcipher-api/                                                                  | todo      | —       |
| `axum-tower.md`          | axum 0.x + tower middleware       | https://docs.rs/axum + https://github.com/tokio-rs/axum/tree/main/examples                                       | todo      | —       |
| `tokio-patterns.md`      | tokio async patterns              | https://tokio.rs/tokio/tutorial + https://docs.rs/tokio (select!, channels, graceful shutdown)                   | todo      | —       |

## Tier 3 — compliance / release / supply-chain (raise during M8/M9)

| Reference                | Topic                              | Source                                                                                                          | Status | Updated |
| ------------------------ | ---------------------------------- | --------------------------------------------------------------------------------------------------------------- | ------ | ------- |
| `owasp-asvs-l2.md`       | OWASP ASVS 4.0.3, Level 2         | https://owasp.org/www-project-application-security-verification-standard/ + GitHub OWASP/ASVS release           | todo      | —       |
| `wcag-2.1-aa.md`         | WCAG 2.1 AA success criteria      | https://www.w3.org/TR/WCAG21/ + https://www.w3.org/WAI/WCAG21/quickref/?versions=2.1&levels=aa                  | todo      | —       |
| `slsa-level-2.md`        | SLSA Build Level 2                | https://slsa.dev/spec/v1.0/levels#build-l2                                                                       | todo      | —       |
| `cosign-sign.md`         | cosign / sigstore signing         | https://docs.sigstore.dev/cosign/overview/                                                                       | todo      | —       |
| `cyclonedx-sbom.md`      | CycloneDX SBOM spec               | https://cyclonedx.org/specification/overview/ + https://docs.rs/cargo-cyclonedx                                  | todo      | —       |
| `gdpr-art-9.md`          | GDPR Article 9 (health data)      | https://gdpr-info.eu/art-9-gdpr/ + https://edpb.europa.eu (guidelines on processing health data)                | todo      | —       |
| `mcp-security.md`        | MCP security best practices       | https://modelcontextprotocol.io/docs/concepts/security (or replace once a separate security doc from Anthropic ships) | todo      | —       |

## Tier 4 — stack-specific, fetch when needed

| Reference                | Topic                              | Source                                                                                                          | Status | Updated |
| ------------------------ | ---------------------------------- | --------------------------------------------------------------------------------------------------------------- | ------ | ------- |
| `tauri-bundler.md`       | tauri-bundler configs              | https://tauri.app/v1/guides/building/cross-platform + https://docs.rs/tauri-bundler                              | todo      | —       |
| `cargo-zigbuild.md`      | Cross-compile matrix              | https://github.com/rust-cross/cargo-zigbuild + https://github.com/cross-rs/cross                                 | todo      | —       |
| `htmx-reference.md`      | htmx 2.x reference                | https://htmx.org/reference/ + https://htmx.org/docs/                                                             | todo      | —       |
| `tracing-json.md`        | tracing JSON output patterns      | https://docs.rs/tracing-subscriber/latest/tracing_subscriber/fmt/format/struct.Json.html                         | todo      | —       |
| `aes-gcm-argon2.md`      | aes-gcm crate + argon2 KDF        | https://docs.rs/aes-gcm + https://docs.rs/argon2 + RFC 9106 (Argon2)                                            | todo      | —       |
| `secrecy-zeroize.md`     | secrecy + zeroize patterns        | https://docs.rs/secrecy + https://docs.rs/zeroize                                                                | todo      | —       |

## Local "references" that should NOT be fetched

These are project artifacts — AI agents must read them before every task, but not via `/aif-reference`:

- `.ai-factory/DESCRIPTION.md` — product, goals, invariants, stack.
- `.ai-factory/ARCHITECTURE.md` — Modular Monolith + Hexagonal, dependency rules.
- `.ai-factory/ROADMAP.md` — milestones M1-M9.
- `docs/01-business-requirements.md` … `docs/08-threat-model.md` — pre-implementation specifications.
- `.ai-factory/rules/{base,security,fhir,mcp}.md` — empty, populated via `/aif-rules`.

## How this integrates with other skills

When a reference appears in this directory — add a link to it in the corresponding rule under `.ai-factory/rules/`:

```markdown
## References
- For the MCP wire protocol see `.ai-factory/references/mcp-spec.md`
- For FHIR R4 resources see `.ai-factory/references/fhir-r4-core.md`
- For OAuth 2.1 + PKCE see `.ai-factory/references/oauth-2.1-pkce.md`
```

This makes the reference automatically "mentioned" for `/aif-plan`, `/aif-implement`, `/aif-grounded` via RULES.md.
