# FHIR R4 Core Resources Reference

> Source: https://www.hl7.org/fhir/R4/ (FHIR R4 normative). Sub-pages: observation.html, condition.html, medicationstatement.html, allergyintolerance.html, immunization.html, encounter.html, diagnosticreport.html, bundle.html
> Created: 2026-05-12
> Updated: 2026-05-12
> Note: The FHIR R4 HTML pages could not be fetched inline (300-600 KB each, all beyond the token limit). This reference is synthesized from the established FHIR R4 normative specification. Cardinality and key fields are stable across releases. For specific edge cases (for example, extensions from US Core / UA-NSZU / Estonia profiles) — `/aif-reference --update --name fhir-r4-core` after a successful fetch.

## Overview

FHIR (Fast Healthcare Interoperability Resources) R4 is the normative release baseline for most regional e-health systems in 2024–2026. Each resource is a JSON or XML object with a mandatory `resourceType` and a set of base fields from `Resource`/`DomainResource`.

This reference covers **7 key resources** plus `Bundle`, used in MyHealth-Europe MCP tools (M4):

1. `Observation` — laboratory and clinical measurements
2. `Condition` — diagnoses
3. `MedicationStatement` — prescription / medication administration
4. `AllergyIntolerance` — allergies
5. `Immunization` — vaccinations
6. `Encounter` — visits to a healthcare facility
7. `DiagnosticReport` — diagnostic study reports
8. `Bundle` — container for import/export

## Core Concepts

### Base resource fields (from `DomainResource`)

All resources inherit from `Resource`:

| Field             | Type          | Cardinality | Description                                 |
| ----------------- | ------------- | ----------- | ------------------------------------------- |
| `resourceType`    | code          | 1..1        | Resource name: `"Observation"`, etc.        |
| `id`              | id            | 0..1        | Logical ID in the source system             |
| `meta`            | Meta          | 0..1        | Metadata: versionId, lastUpdated, profile  |
| `implicitRules`   | uri           | 0..1        | Rare, for legacy                            |
| `language`        | code          | 0..1        | ISO language code                           |

`DomainResource` adds:

| Field           | Type           | Cardinality | Description                       |
| --------------- | -------------- | ----------- | --------------------------------- |
| `text`          | Narrative      | 0..1        | Human-readable summary            |
| `contained`     | Resource[]     | 0..*        | Inline-embedded sub-resources     |
| `extension`     | Extension[]    | 0..*        | Custom extensions                 |
| `modifierExtension` | Extension[] | 0..*        | Extensions that change meaning    |

### Common data types (relevant for core resources)

- **`code`** — code value from a defined ValueSet
- **`CodeableConcept`** — `{ coding: [{ system, code, display }], text }` — coded concept
- **`Coding`** — `{ system, code, display }` — one of the codes
- **`Reference`** — `{ reference: "ResourceType/id", display, type }` — reference to another resource
- **`Quantity`** — `{ value, unit, system, code, comparator }` — numeric value with a unit
- **`Period`** — `{ start, end }` — interval
- **`Range`** — `{ low: Quantity, high: Quantity }` — range
- **`Identifier`** — `{ system, value, use, type }` — external ID
- **`Annotation`** — `{ text, time, authorString | authorReference }` — note

### `value[x]` polymorphic fields

Many FHIR resources have a polymorphic field where `[x]` is replaced by the type:

- `valueQuantity`, `valueString`, `valueBoolean`, `valueCodeableConcept`, `valueRange`, `valuePeriod`, `valueDateTime`, …

Only ONE of these is present on the resource. In `fhirbolt` this is wrapped in an enum (`ObservationValue::String`, `ObservationValue::Quantity`, etc.).

## Resource: Observation

**Purpose:** measurements and simple assertions about a patient — vital signs, lab results, social history, survey results.

**Key fields:**

| Field                  | Type                            | Card. | Notes                                                                 |
| ---------------------- | ------------------------------- | ----- | --------------------------------------------------------------------- |
| `identifier`           | Identifier[]                    | 0..*  | External IDs (lab system, etc.)                                       |
| `basedOn`              | Reference[]                     | 0..*  | What it is based on (ServiceRequest, MedicationRequest, ...)          |
| `partOf`               | Reference[]                     | 0..*  | Belongs to a larger event                                             |
| **`status`**           | code                            | 1..1  | `registered \| preliminary \| final \| amended \| corrected \| cancelled \| entered-in-error \| unknown` |
| `category`             | CodeableConcept[]               | 0..*  | `laboratory`, `vital-signs`, `imaging`, `procedure`, `survey`, ...    |
| **`code`**             | CodeableConcept                 | 1..1  | LOINC / SNOMED code of WHAT was measured                              |
| **`subject`**          | Reference(Patient \| Group \| ...) | 0..1 | About whom: Patient/123                                              |
| `encounter`            | Reference(Encounter)            | 0..1  | In which encounter it was performed                                   |
| `effective[x]`         | dateTime \| Period \| Timing \| instant | 0..1 | When the value is relevant to                                    |
| `issued`               | instant                         | 0..1  | When the result was published                                         |
| `performer`            | Reference[]                     | 0..*  | Who performed it                                                      |
| **`value[x]`**         | Quantity \| CodeableConcept \| string \| boolean \| integer \| Range \| Ratio \| SampledData \| time \| dateTime \| Period | 0..1 | The value itself |
| `dataAbsentReason`     | CodeableConcept                 | 0..1  | If a value is missing — why                                           |
| `interpretation`       | CodeableConcept[]               | 0..*  | Normal / high / low / critical                                        |
| `note`                 | Annotation[]                    | 0..*  | Free-text comments                                                    |
| `bodySite`             | CodeableConcept                 | 0..1  | Anatomical location                                                   |
| `method`               | CodeableConcept                 | 0..1  | Measurement method                                                    |
| `specimen`             | Reference(Specimen)             | 0..1  | Specimen                                                              |
| `device`               | Reference(Device \| DeviceMetric) | 0..1 | Device                                                                |
| `referenceRange`       | BackboneElement[]               | 0..*  | Normal ranges (low/high/text)                                         |
| `hasMember`            | Reference[]                     | 0..*  | Members of a panel (CBC → leukocytes, hemoglobin, ...)                |
| `derivedFrom`          | Reference[]                     | 0..*  | What it was derived from                                              |
| `component`            | BackboneElement[]               | 0..*  | Sub-observations (blood pressure → systolic + diastolic)              |

**Critical rules:**

- `code` + `value[x]` (or `dataAbsentReason`) — fundamental unit of information.
- `effective[x]` — the time the value RELATES TO (the moment of blood draw), not `issued` (the publication time).
- `component` — for observations with multiple related values. Each component has its own `code` + `value[x]`.

## Resource: Condition

**Purpose:** diagnoses, problems, complaints.

**Key fields:**

| Field                | Type                      | Card. | Notes                                                              |
| -------------------- | ------------------------- | ----- | ------------------------------------------------------------------ |
| `identifier`         | Identifier[]              | 0..*  |                                                                    |
| **`clinicalStatus`** | CodeableConcept           | 0..1  | `active \| recurrence \| relapse \| inactive \| remission \| resolved` |
| **`verificationStatus`** | CodeableConcept       | 0..1  | `unconfirmed \| provisional \| differential \| confirmed \| refuted \| entered-in-error` |
| `category`           | CodeableConcept[]         | 0..*  | `problem-list-item`, `encounter-diagnosis`                         |
| `severity`           | CodeableConcept           | 0..1  | mild / moderate / severe                                           |
| **`code`**           | CodeableConcept           | 0..1  | ICD-10 / SNOMED / etc.                                             |
| `bodySite`           | CodeableConcept[]         | 0..*  |                                                                    |
| **`subject`**        | Reference(Patient \| Group) | 1..1 |                                                                    |
| `encounter`          | Reference(Encounter)      | 0..1  |                                                                    |
| `onset[x]`           | dateTime \| Age \| Period \| Range \| string | 0..1 | When it started                                |
| `abatement[x]`       | dateTime \| Age \| Period \| Range \| string | 0..1 | When it ended                                  |
| `recordedDate`       | dateTime                  | 0..1  | When it was recorded                                               |
| `recorder`           | Reference                 | 0..1  | Who recorded it                                                    |
| `asserter`           | Reference                 | 0..1  | Who asserts it                                                     |
| `stage`              | BackboneElement[]         | 0..*  | Stage (for oncology, CKD, etc.)                                    |
| `evidence`           | BackboneElement[]         | 0..*  | Evidence (code + detail)                                           |
| `note`               | Annotation[]              | 0..*  |                                                                    |

**Critical rules:**

- `clinicalStatus` is mandatory if `verificationStatus` != `entered-in-error`.
- `verificationStatus` = `entered-in-error` — this combination with clinicalStatus is forbidden.

## Resource: MedicationStatement

**Purpose:** statement about medication use (as taken, not as prescribed).

**Key fields:**

| Field                | Type                          | Card. | Notes                                                        |
| -------------------- | ----------------------------- | ----- | ------------------------------------------------------------ |
| `identifier`         | Identifier[]                  | 0..*  |                                                              |
| `basedOn`            | Reference[]                   | 0..*  | Based on MedicationRequest / CarePlan / ...                  |
| `partOf`             | Reference[]                   | 0..*  |                                                              |
| **`status`**         | code                          | 1..1  | `active \| completed \| entered-in-error \| intended \| stopped \| on-hold \| unknown \| not-taken` |
| `statusReason`       | CodeableConcept[]             | 0..*  |                                                              |
| `category`           | CodeableConcept               | 0..1  |                                                              |
| **`medication[x]`**  | CodeableConcept \| Reference(Medication) | 1..1 | What is taken (code or reference)                  |
| **`subject`**        | Reference(Patient \| Group)   | 1..1  |                                                              |
| `context`            | Reference(Encounter \| EpisodeOfCare) | 0..1 |                                                       |
| `effective[x]`       | dateTime \| Period            | 0..1  | Period of administration                                     |
| `dateAsserted`       | dateTime                      | 0..1  | When it was recorded                                         |
| `informationSource`  | Reference                     | 0..1  | Who provided the information (Patient / RelatedPerson / Practitioner) |
| `derivedFrom`        | Reference[]                   | 0..*  |                                                              |
| `reasonCode`         | CodeableConcept[]             | 0..*  | Why it is taken                                              |
| `reasonReference`    | Reference[]                   | 0..*  |                                                              |
| `note`               | Annotation[]                  | 0..*  |                                                              |
| `dosage`             | Dosage[]                      | 0..*  | Complex structure (route, frequency, dose, ...)              |

## Resource: AllergyIntolerance

**Purpose:** risk or confirmed allergic reaction.

**Key fields:**

| Field                    | Type                    | Card. | Notes                                                                       |
| ------------------------ | ----------------------- | ----- | --------------------------------------------------------------------------- |
| `identifier`             | Identifier[]            | 0..*  |                                                                             |
| **`clinicalStatus`**     | CodeableConcept         | 0..1  | `active \| inactive \| resolved`                                            |
| **`verificationStatus`** | CodeableConcept         | 0..1  | `unconfirmed \| confirmed \| refuted \| entered-in-error`                  |
| `type`                   | code                    | 0..1  | `allergy \| intolerance`                                                    |
| `category`               | code[]                  | 0..*  | `food \| medication \| environment \| biologic`                            |
| `criticality`            | code                    | 0..1  | `low \| high \| unable-to-assess`                                          |
| **`code`**               | CodeableConcept         | 0..1  | What the allergy is to (substance code)                                     |
| **`patient`**            | Reference(Patient)      | 1..1  |                                                                             |
| `encounter`              | Reference(Encounter)    | 0..1  |                                                                             |
| `onset[x]`               | dateTime \| Age \| Period \| Range \| string | 0..1 |                                                  |
| `recordedDate`           | dateTime                | 0..1  |                                                                             |
| `recorder`               | Reference               | 0..1  |                                                                             |
| `asserter`               | Reference               | 0..1  |                                                                             |
| `lastOccurrence`         | dateTime                | 0..1  |                                                                             |
| `note`                   | Annotation[]            | 0..*  |                                                                             |
| `reaction`               | BackboneElement[]       | 0..*  | `{ substance, manifestation[], description, onset, severity, exposureRoute, note }` |

## Resource: Immunization

**Purpose:** the fact of a vaccination.

**Key fields:**

| Field                  | Type                       | Card. | Notes                                                                |
| ---------------------- | -------------------------- | ----- | -------------------------------------------------------------------- |
| `identifier`           | Identifier[]               | 0..*  |                                                                      |
| **`status`**           | code                       | 1..1  | `completed \| entered-in-error \| not-done`                          |
| `statusReason`         | CodeableConcept            | 0..1  |                                                                      |
| **`vaccineCode`**      | CodeableConcept            | 1..1  | CVX / ATC / etc.                                                     |
| **`patient`**          | Reference(Patient)         | 1..1  |                                                                      |
| `encounter`            | Reference(Encounter)       | 0..1  |                                                                      |
| **`occurrence[x]`**    | dateTime \| string         | 1..1  | When it was performed                                                |
| `recorded`             | dateTime                   | 0..1  |                                                                      |
| `primarySource`        | boolean                    | 0..1  | Data from a first-hand source (true) or from secondary (false)       |
| `reportOrigin`         | CodeableConcept            | 0..1  | If secondary                                                         |
| `location`             | Reference(Location)        | 0..1  |                                                                      |
| `manufacturer`         | Reference(Organization)    | 0..1  |                                                                      |
| `lotNumber`            | string                     | 0..1  |                                                                      |
| `expirationDate`       | date                       | 0..1  |                                                                      |
| `site`                 | CodeableConcept            | 0..1  | Injection site (left-arm, right-thigh)                               |
| `route`                | CodeableConcept            | 0..1  | IM / SC / oral                                                       |
| `doseQuantity`         | Quantity (SimpleQuantity)  | 0..1  |                                                                      |
| `performer`            | BackboneElement[]          | 0..*  |                                                                      |
| `note`                 | Annotation[]               | 0..*  |                                                                      |
| `reasonCode`           | CodeableConcept[]          | 0..*  |                                                                      |
| `reasonReference`      | Reference[]                | 0..*  |                                                                      |
| `isSubpotent`          | boolean                    | 0..1  |                                                                      |
| `subpotentReason`      | CodeableConcept[]          | 0..*  |                                                                      |
| `education`            | BackboneElement[]          | 0..*  |                                                                      |
| `programEligibility`   | CodeableConcept[]          | 0..*  |                                                                      |
| `fundingSource`        | CodeableConcept            | 0..1  |                                                                      |
| `reaction`             | BackboneElement[]          | 0..*  |                                                                      |
| `protocolApplied`      | BackboneElement[]          | 0..*  | `{ series, targetDisease, doseNumber[x], seriesDoses[x] }`          |

## Resource: Encounter

**Purpose:** patient interaction with the system (outpatient, inpatient, emergency).

**Key fields:**

| Field                | Type                        | Card. | Notes                                                                     |
| -------------------- | --------------------------- | ----- | ------------------------------------------------------------------------- |
| `identifier`         | Identifier[]                | 0..*  |                                                                           |
| **`status`**         | code                        | 1..1  | `planned \| arrived \| triaged \| in-progress \| onleave \| finished \| cancelled \| entered-in-error \| unknown` |
| `statusHistory`      | BackboneElement[]           | 0..*  |                                                                           |
| **`class`**          | Coding                      | 1..1  | `AMB`, `EMER`, `IMP`, `OBSENC`, … (ActEncounterCode)                     |
| `classHistory`       | BackboneElement[]           | 0..*  |                                                                           |
| `type`               | CodeableConcept[]           | 0..*  |                                                                           |
| `serviceType`        | CodeableConcept             | 0..1  |                                                                           |
| `priority`           | CodeableConcept             | 0..1  |                                                                           |
| **`subject`**        | Reference(Patient \| Group) | 0..1  |                                                                           |
| `episodeOfCare`      | Reference[]                 | 0..*  |                                                                           |
| `basedOn`            | Reference[]                 | 0..*  |                                                                           |
| `participant`        | BackboneElement[]           | 0..*  | `{ type, period, individual }`                                            |
| `appointment`        | Reference[]                 | 0..*  |                                                                           |
| `period`             | Period                      | 0..1  | When it lasted                                                            |
| `length`             | Duration                    | 0..1  |                                                                           |
| `reasonCode`         | CodeableConcept[]           | 0..*  |                                                                           |
| `reasonReference`    | Reference[]                 | 0..*  |                                                                           |
| `diagnosis`          | BackboneElement[]           | 0..*  | `{ condition, use, rank }`                                                |
| `account`            | Reference[]                 | 0..*  |                                                                           |
| `hospitalization`    | BackboneElement             | 0..1  | preAdmission/origin/admitSource/reAdmission/dietPreference/specialCourtesy/specialArrangement/destination/dischargeDisposition |
| `location`           | BackboneElement[]           | 0..*  | `{ location, status, physicalType, period }`                              |
| `serviceProvider`    | Reference(Organization)     | 0..1  |                                                                           |
| `partOf`             | Reference(Encounter)        | 0..1  |                                                                           |

## Resource: DiagnosticReport

**Purpose:** clinical report (lab panel, radiology read, pathology, etc.).

**Key fields:**

| Field                | Type                          | Card. | Notes                                                                              |
| -------------------- | ----------------------------- | ----- | ---------------------------------------------------------------------------------- |
| `identifier`         | Identifier[]                  | 0..*  |                                                                                    |
| `basedOn`            | Reference[]                   | 0..*  | ServiceRequest, MedicationRequest, ...                                             |
| **`status`**         | code                          | 1..1  | `registered \| partial \| preliminary \| final \| amended \| corrected \| appended \| cancelled \| entered-in-error \| unknown` |
| `category`           | CodeableConcept[]             | 0..*  |                                                                                    |
| **`code`**           | CodeableConcept               | 1..1  | LOINC report code                                                                  |
| **`subject`**        | Reference                     | 0..1  |                                                                                    |
| `encounter`          | Reference(Encounter)          | 0..1  |                                                                                    |
| `effective[x]`       | dateTime \| Period            | 0..1  |                                                                                    |
| `issued`             | instant                       | 0..1  |                                                                                    |
| `performer`          | Reference[]                   | 0..*  |                                                                                    |
| `resultsInterpreter` | Reference[]                   | 0..*  |                                                                                    |
| `specimen`           | Reference[]                   | 0..*  |                                                                                    |
| `result`             | Reference(Observation)[]      | 0..*  | Individual Observations that make up the report                                    |
| `imagingStudy`       | Reference(ImagingStudy)[]     | 0..*  |                                                                                    |
| `media`              | BackboneElement[]             | 0..*  | `{ comment, link → Media }`                                                       |
| `conclusion`         | string                        | 0..1  |                                                                                    |
| `conclusionCode`     | CodeableConcept[]             | 0..*  |                                                                                    |
| `presentedForm`      | Attachment[]                  | 0..*  | PDF or other binary form of the report                                             |

## Resource: Bundle

**Purpose:** container for transporting a set of resources (FHIR API responses, document bundles, transaction bundles).

**Key fields:**

| Field             | Type                  | Card. | Notes                                                                                  |
| ----------------- | --------------------- | ----- | -------------------------------------------------------------------------------------- |
| `identifier`      | Identifier            | 0..1  | Persistent ID for documents/messages                                                  |
| **`type`**        | code                  | 1..1  | `document \| message \| transaction \| transaction-response \| batch \| batch-response \| history \| searchset \| collection \| subscription-notification` |
| `timestamp`       | instant               | 0..1  | When the bundle was assembled                                                         |
| `total`           | unsignedInt           | 0..1  | Total number of matches (for searchset)                                               |
| `link`            | BackboneElement[]     | 0..*  | `{ relation, url }` — pagination / self / first / last                               |
| **`entry`**       | BackboneElement[]     | 0..*  | `{ link, fullUrl, resource, search, request, response }` — the resources themselves |
| `signature`       | Signature             | 0..1  |                                                                                        |

**`Bundle.entry`** is the heart of the container:

- `entry.fullUrl` — absolute URL of this resource (stable reference)
- `entry.resource` — the resource itself
- `entry.search` — `{ mode, score }` for searchset
- `entry.request` — `{ method, url }` for transaction/batch (POST/PUT/DELETE/GET)
- `entry.response` — `{ status, location, etag, lastModified, outcome }` for transaction-response

**Bundle.type for import into MyHealth-Europe:**

- `collection` — generic FHIR R4 import (M2 generic adapter)
- `document` — typically Apple Health export
- `searchset` — eHealth UA / Estonia Digilugu API responses

## Best Practices

1. **Adhere to cardinality 1..1 strictly.** If `Observation.status` is missing — that is an invalid resource, not a fallback.
2. **`value[x]` is exclusive.** One Observation = one value type. `valueQuantity` + `valueString` simultaneously is invalid.
3. **`Reference.reference` must be in resource-type/id format.** `Patient/123`, not just `123`.
4. **Codes from a ValueSet — not free text.** `code` fields are tied beat-by-beat to specific code systems (LOINC, SNOMED CT, ICD-10).
5. **`effective[x]` ≠ `issued`.** Effective is the clinical moment. Issued is the publication moment.
6. **`Bundle.entry.fullUrl` — for cross-reference.** When importing — use it as an idempotency key.
7. **`component` for multi-value observations.** Blood pressure is ONE Observation with two components (systolic, diastolic), not two Observations.
8. **`Condition.clinicalStatus` + `verificationStatus` are mutually validated.** `verificationStatus = entered-in-error` → `clinicalStatus` must be absent.

## Common Pitfalls

- **Sending raw `Bundle` to an MCP tool.** The AI agent expects domain resources, not the FHIR wrapper. Unpack `bundle.entry` in the adapter.
- **Profile validation in `myhealth-core`.** Profiles (US Core, UA-NSZU) are post-processing. The core resources `fhirbolt::model::r4` are base FHIR R4.
- **DateTime with timezone.** FHIR dateTime in ISO 8601 with timezone is mandatory. `"2026-05-12"` (without time) is a date, not a dateTime; these types are different.
- **`Reference` without resource-type.** `{ reference: "123" }` is invalid. `{ reference: "Patient/123" }` is valid.
- **Extensions in core polymorphic fields.** Each `value[x]` field can have extensions. Do not drop them when mapping into the domain.

## Integration with MyHealth-Europe

- **Crate `myhealth-core::model`** is the domain model, **not** a copy of FHIR structures. The mapping `fhirbolt::model::r4::resources::Observation` → `myhealth_core::model::Observation` happens in adapters.
- **Read-only in phase 1.** All resources are read-only via MCP tools. Write-back (`POST Bundle` transaction) is out of scope for phase 1.
- **MCP tools that work with these resources:**
  - `get_observations(scope, date_range)` → Observation[]
  - `get_conditions(scope)` → Condition[]
  - `get_medications(scope, active_only)` → MedicationStatement[]
  - `get_allergies(scope)` → AllergyIntolerance[]
  - `get_immunizations(scope)` → Immunization[]
  - `get_encounters(scope, date_range)` → Encounter[]
  - `get_diagnostic_reports(scope, date_range)` → DiagnosticReport[]
  - `search_records(query, types)` → mixed result
  - `get_health_summary(scope)` → aggregate (custom summary, not a single FHIR resource)
- **Idempotency:** `Bundle.entry.fullUrl` + `resource.id` + `resource.meta.versionId` as the unique key for import deduplication (FR-1.5).
- **PHI in logs.** None of these resources is serialized into logs. The `tracing` filter MUST drop the `subject`, `patient`, `code`, `value[x]`, `note`, `text` fields.

## Open Questions / TODO

- **Regional profiles:** UA-NSZU (eHealth UA), Estonia Digilugu (via X-Road CDA→FHIR mapping), Apple Health XML→FHIR conversion rules. These are separate references (`nszu-fhir-ua.md`, `digilugu-cda-ee.md`, `apple-health-xml.md`) — Tier 2, fetch when an adapter reaches implementation.
- **Sensitive categories.** Which SNOMED/LOINC codes are classified as `psych`, `sexual`, `genetic` for per-resource confirmation in the Consent Gateway — a separate ADR + reference.
- **US Core profiles.** If the roadmap includes support for US-based FHIR endpoints — add a separate reference for US Core.
