//! Adapter Layer: convert source-specific health data into canonical FHIR R4.
//!
//! Submodules (planned, see docs/06-architecture.md §2.1):
//! - `ehealth_ua`   — NSZU-FHIR (Ukraine)
//! - `digilugu_ee`  — Estonia Digilugu R4 + CDA→FHIR for legacy bundles
//! - `apple_health` — iOS XML/FHIR export
//! - `generic_fhir_r4` — pass-through for compliant R4 bundles
//!
//! The trait contract is `pub trait Adapter` — see PRD FR-1.* and architecture doc.
