# fhirbolt Reference

> Source: https://docs.rs/fhirbolt/latest/fhirbolt/, https://github.com/lschmierer/fhirbolt
> Created: 2026-05-12
> Updated: 2026-05-12

## Overview

`fhirbolt` is a Rust crate for working with FHIR resources. It supports (de)serialization to/from **JSON and XML**. It currently covers **FHIR R4, R4B, and R5**. Future features (validation with cardinality/slicing, full FHIRPath evaluation) are not yet implemented.

Version at the time this reference was created: **0.4.0**. The crate is fully documented (100% per docs.rs metrics). License: MIT OR Apache-2.0. Owner: `lschmierer`.

## Core Concepts

**Two operating modes:**

1. **Generic element model** (the `element` module) — untyped work with FHIR resources via a generalized `Element` (analogous to `serde_json::Value`). Useful for transformations without knowing the concrete resource type.
2. **Fully typed model structs** (the `model` module) — generated Rust structures for each FHIR resource. Type-safe, with autocomplete support and cardinality enforcement at the type level (`Option<T>`, `Vec<T>`).

**FHIR release as a Cargo feature.** By default no release is enabled — you must specify it explicitly:

```toml
[dependencies]
fhirbolt = { version = "0.4", features = ["r4b"] }
```

Available features: `r4`, `r4b`, `r5`. You can enable several in parallel — then resources from different releases live under the corresponding `fhirbolt::model::r4::`, `fhirbolt::model::r4b::`, `fhirbolt::model::r5::`.

## API / Interface

**Re-exports from the crate root:**

- `pub use serde::json` — JSON (de)serialization
- `pub use serde::xml` — XML (de)serialization

**Modules:**

| Module           | Purpose                                                    |
| ---------------- | ---------------------------------------------------------- |
| `FhirReleases`   | Enumeration of supported FHIR Releases                     |
| `element`        | Generic element model (untyped operations)                 |
| `model`          | Generated structs per release: `r4::`, `r4b::`, `r5::`     |
| `serde`          | (De)serialization to/from JSON and XML; deserialization configs |

**Type Aliases:**

- `FhirRelease` — generic FHIR Release type

**Internal dependencies of the fhirbolt workspace:**

- `fhirbolt-element` ^0.4.0 — generic Element implementation
- `fhirbolt-model` ^0.4.0 (optional) — generated structures
- `fhirbolt-serde` ^0.4.0 — serde integration
- `fhirbolt-shared` ^0.4.0 — shared types

## Usage Patterns

### Deserializing JSON into the `Resource` enum

`Resource` is an enum that contains all possible FHIR resources. If the type is not known in advance — deserialize into it and match on the variants:

```rust
use fhirbolt::model::r4b::{
    Resource,
    resources::{Observation, ObservationValue},
    types::{Code, CodeableConcept, Coding, String as FhirString},
};
use fhirbolt::serde::{DeserializationConfig, DeserializationMode};

let s = r#"{
    "resourceType": "Observation",
    "status": "final",
    "code": {
        "text": "some code"
    },
    "valueString": "some value"
}"#;

let r: Resource = fhirbolt::json::from_str(s, None).unwrap();

match r {
    Resource::Observation(ref o) => println!("deserialized observation: {:?}", r),
    _ => (),
}
```

### Constructing a resource manually

If the resource type is known — use the concrete struct and `Default::default()`:

```rust
let o = Observation {
    status: "final".into(),
    code: Box::new(CodeableConcept {
        text: Some("some code".into()),
        ..Default::default()
    }),
    value: Some(ObservationValue::String("some value".into())),
    ..Default::default()
};
```

### Deserialization config

Pass `Option<DeserializationConfig>` as the second argument to `from_str`. The config controls the mode (for example, strict vs. lax JSON type validation). Details — in `fhirbolt::serde::DeserializationConfig` and `DeserializationMode`.

## Configuration

| Option                                      | Purpose                                                                       |
| ------------------------------------------- | ----------------------------------------------------------------------------- |
| Feature `r4`                                | Enables `fhirbolt::model::r4::*`                                              |
| Feature `r4b`                               | Enables `fhirbolt::model::r4b::*`                                             |
| Feature `r5`                                | Enables `fhirbolt::model::r5::*`                                              |
| `DeserializationConfig.mode` = `Strict`     | Strict validation of field formats                                            |
| `DeserializationConfig.mode` = `Compatible` | More tolerant mode (for legacy data)                                          |

## Best Practices

1. **Always enable only the FHIR releases you need** — each release adds hundreds of generated structs (a large portion of the binary). For the MyHealth-Europe project this is `r4`.
2. **For adapters** (`crates/adapters/*`) — use the typed structs from `model::r4::*`, not the generic `element`. Type safety provides compile-time cardinality checking.
3. **For parsing a bundle where the type is unknown** — deserialize into the `Resource` enum, then match. If you know the type — deserialize directly into the concrete struct.
4. **`Box::new(...)` for large nested structures** — generated FHIR structures are deep, `Box` reduces stack pressure.
5. **`..Default::default()`** — the standard for partial population; FHIR structures have very many optional fields.
6. **Pass `None` as `DeserializationConfig`** for the default strict mode. If "dirty" FHIR arrives (Apple Health XML, regional deviations) — try `Compatible`.

## Common Pitfalls

- **Forgetting the feature flag.** By default `model::r4` does not exist. The build will compile without errors, but the imports will not resolve.
- **Mixing releases.** `model::r4::resources::Observation` and `model::r4b::resources::Observation` are different types and not directly convertible. If a crosswalk between releases is needed — write your own transform layer.
- **Leaving validation to the compiler.** `fhirbolt` does NOT perform slicing/cardinality validation at runtime — it only parses the structure. FHIR business rules (for example, `Observation.value[x]` being exclusive) must be checked yourself.
- **Binary size.** Enabling `r4` + `r4b` + `r5` noticeably bloats the binary. For a self-hosted single-binary value proposition — pick **one** release.

## Version Notes

- **0.4.0** — current stable. Supports R4, R4B, R5.
- The API is not yet stabilizing — minor versions may introduce breaking changes in `model::*` structures when FHIR schemas update.
- The repo documentation shows examples with `version = "0.2"` — that is deprecated; in the MyHealth-Europe project use `0.4`.

## Integration with MyHealth-Europe

- **Adapter crates** (`crates/adapters/adapter-ua-nszu`, `adapter-ee-digilugu`, `adapter-apple`, `adapter-generic-r4`) — import `fhirbolt::model::r4::*` for typed FHIR R4 resources.
- **Cargo feature pinning:** `fhirbolt = { version = "0.4", features = ["r4"] }`. R4B/R5 must not be enabled in phase 1.
- **Pipeline:** raw bytes → `fhirbolt::json::from_str` (or `xml::from_str` for Apple Health) → `Resource` enum → match → mapping into the domain `myhealth_core::model::*`.
- **Do not surface `fhirbolt::*` in `myhealth-core`.** The domain crate must be runtime-agnostic, with no serde on REST-API types. Conversion from `fhirbolt::model::r4::resources::Observation` to `myhealth_core::model::Observation` happens in the adapter.
