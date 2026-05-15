# FHIR Rules

> Conventions for FHIR parsers and adapters (`crates/adapters/*`).
> Loaded after `rules/base.md` for FHIR-related code.

## Rules

- All adapters implement a **single trait `FhirImporter`** from `myhealth-core::ports`. Separate trait hierarchies per source are forbidden.
- Adapters depend **only** on `myhealth-core` (per `Cargo.toml`). Reach-in to other crates (`myhealth-store`, `myhealth-mcp`, …) is a compile-time error via `pub(crate)` boundaries.
- An adapter never imports another adapter (`adapter-ua-nszu` ↛ `adapter-ee-digilugu`). Common logic moves into `myhealth-core::fhir::common`.
- Strong-typed FHIR R4 models via `fhirbolt` — no `serde_json::Value` in the adapter's public API.
- FHIR R5 is out of scope for phase 1 (FR-1.x). Do not add R5-specific code in adapters until an explicit M-pivot.
- `source_id()` of an adapter — a stable `&'static str` in kebab-case: `"ua-nszu"`, `"ee-digilugu"`, `"apple-health"`, `"generic-r4"`. Used in audit log and error tracking.
- **Idempotent re-import** (FR-1.5): re-importing the same bundle → `count_new = 0`, `count_existing = N`, no duplicates. Detection — via FHIR `Resource.id` + content-hash, not by id alone.
- **Partial recovery** (FR-1.7): invalid records are collected into quarantine with a reason; valid ones are imported. An adapter never fails the entire bundle because of one invalid entry.
- **Streaming parser** with a max file size of 250 MB by default (T-A3). Do not load the entire bundle into memory at once.
- **Safe XML parser** (defused-style) for the CDA→FHIR converter in `adapter-ee-digilugu`; JSON parser with depth/size limits for all adapters (T-A1).
- An adapter **never writes PHI to logs**. Instead of `tracing::info!("imported {bundle:?}")` use `tracing::info!(record_count = bundle.entries.len(), source = %self.source_id(), "import completed")`.
- `ImportSummary` returns only aggregated metadata: `count_by_resource_type`, `date_range_min/max`, `validation_errors_count`, `quarantine_count`. No PHI in `ImportSummary`.
- Schema validation against the FHIR R4 specification is mandatory. `fhirbolt-shared` for the basic validation + custom business-rule validators.
- Dates are normalised to ISO 8601 UTC inside the store; the adapter is responsible for normalising the source-specific format (Digilugu Estonian local time, NSZU Kyiv time, Apple Health UTC).
- Language tagging (`Resource.language` + `Coding.display`) is preserved without translation. Translation is the reference agent's job (M7), not the adapter's.
- NSZU extensions (`adapter-ua-nszu`) are parsed into explicit Rust structs; unknown extensions land in `unknown_extensions: Vec<RawExtension>` with a warning in `ImportSummary`.
- Apple Health XML → FHIR (`adapter-apple`): the mapping table HKQuantityTypeIdentifier → FHIR `Observation.code` lives in `adapter-apple/src/mappings.rs`; each addition is a separate ADR.
- **Property-based testing** via `proptest` is mandatory for all adapters: roundtrip parse → serialize → parse, idempotency, valid vs invalid bundle inputs (T-A4).
- **Fuzz testing** for the CDA→FHIR converter in M3 — target ≥80% mutation score via `cargo fuzz`.
- Test FHIR fixtures are **synthetic** (CC0 license), generated via Synthea or by hand. No plausible PHI even in tests.
- HMAC-MAC is computed at the `myhealth-store` layer after a successful import, not in the adapter. The adapter returns clean domain types via `FhirImporter::import`.
- The adapter does not perform encryption — that is `myhealth-store`'s job. The adapter works strictly with plaintext domain types in memory, which are then encrypted by the store.
- Parsing errors — `CoreError::FhirParse { source: String, line: Option<usize>, kind: ParseErrorKind }`; `kind` is an enum, no free text containing PHI.
- Each new FHIR source = a separate crate `crates/adapters/adapter-<country>-<system>/` + an ADR in `docs/adr/` with the rationale for the mapping and edge cases.
