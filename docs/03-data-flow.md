# 03 — Data Flow

**Document:** MyHealth-Europe — data flow, trust boundaries, what never leaves the perimeter
**Version:** 0.1
**Date:** 2026-05-12
**Owner:** Ruslan Hryban
**Purpose:** **the primary document for understanding the system** — for the review committee, auditors, downstream developers, and any first-time reader.

---

## TL;DR (for the review committee — 60-second read)

**MyHealth-Europe collects nothing and transmits nothing. Everything runs exclusively on the user's device.**

The user is the **sole** controller and the **sole** processor of their data (in GDPR terms). The project team — and indeed anyone who is not the owner of a particular instance — has access to not a single byte of user data. This is not a promise in a privacy policy; it is an architectural fact: there is no project-side backend that could even hypothetically receive that data.

Data moves through the system as follows:

```
   STEP 1 — User              STEP 2 — Self-import         STEP 3 — Request from AI
   ─────────────────────      ─────────────────────        ─────────────────────
   Goes to the national       Places the downloaded        AI agent requests scope
   e-health portal            file into their local        → user approves
   (eHealth UA, Digilugu,     MyHealth-Europe instance     → agent receives a token
   Apple Health) — clicks     → parsing, validation,       with limited access
   "export" there             encryption on the local      → reads only what is
   → receives a file          disk                         allowed
                                                           → write to audit log
```

**Key point:** data enters the system **only** as a file that the user has consciously brought in themselves. It exits **only** in the AI agent's response, which the user reads themselves. No project component "phones home." Telemetry, analytics, crash reports, updates — either fully disabled or opt-in with pseudonymous IDs.

---

## 1. High-level data-flow diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│                    USER ENVIRONMENT (trusted zone)                   │
│                                                                       │
│  ┌─────────────┐        ┌─────────────┐         ┌─────────────────┐ │
│  │ Import      │        │ Local       │         │ MCP server      │ │
│  │ adapters    │──parse─►│ encrypted   │──read──►│ (tools surface) │ │
│  │ FHIR        │  valid. │ store       │  with   │                 │ │
│  │             │         │ (SQLite +   │  scope  │  ┌───────────┐  │ │
│  │ • eHealth UA│         │  AES-GCM)   │         │  │ OAuth 2.1 │  │ │
│  │ • Digilugu  │         │             │         │  │ consent   │  │ │
│  │ • Apple     │         │             │         │  │ gateway   │  │ │
│  │   Health    │         │ ┌─────────┐ │         │  └─────┬─────┘  │ │
│  └─────────────┘         │ │ Audit   │◄┼─────────┼────────┘        │ │
│        ▲                 │ │ log     │ │ record  └─────────┬───────┘ │
│        │                 │ └─────────┘ │ of every          │         │
│        │ file                          │ access            │ MCP     │
│        │ brought                       │                   │ protocol│
│        │ in by                         │                   │ (stdio  │
│        │ the user                      │                   │ / SSE)  │
└────────┼───────────────────────────────┼───────────────────┼─────────┘
         │                               │                   │
         │                               │                   │
   ▲ ─── │ ─── ─── ─── ─── ─── ─── ─── ─ │ ─── ─── ─── ─── ─ │ ─── ─►
   │     │                               │                   │
   │     │  TRUST BOUNDARY               │                   │
   │     │                               │                   │
┌────────┴───────────┐                   │           ┌───────┴────────┐
│ External sources   │                   │           │ AI agent       │
│ (national          │                   │           │ (Claude        │
│ e-health, wearables│                   │           │ Desktop,       │
│ — UA, EE, EU)      │                   │           │ local Llama,   │
│                    │                   │           │ EU-hosted LLM) │
│ The user           │                   │           │                │
│ consciously goes   │                   │           │ Knows nothing  │
│ there and          │                   │           │ about the data │
│ downloads a file.  │                   │           │ until it asks  │
└────────────────────┘                   │           │ for a scope.   │
                                         │           └────────────────┘
                                         │
                                         ▼
                            ┌─────────────────────────┐
                            │ CRITICAL: this store    │
                            │ never leaves the user's │
                            │ environment. No         │
                            │ component has a         │
                            │ "phone home" channel.   │
                            └─────────────────────────┘
```

---

## 2. Data sources (where the data lives BEFORE the user brings it in)

Below is an exhaustive list of sources that phase 1 supports and those planned for phase 2+. In every case, the user is the **only** actor who decides whether and when to export.

### 2.1. Phase 1 (current grant, 3 adapters)

#### Source A — eHealth Ukraine

| Parameter | Value |
|----------|----------|
| Data holder | National Health Service of Ukraine (NHSU) |
| Export format | HL7 FHIR R4 bundle (JSON) |
| How to obtain | Patient request via the official patient cabinet (helsi.me or analogue) or written request to the NHSU |
| Authorisation | Qualified electronic signature (QES) or Diia signature |
| Regulatory basis | Law "Fundamentals of the Legislation on Health Care", art. 39 (patient's right to medical information) |
| Technical caveats | Bulk export may be incomplete for records created before 2020; some providers are still not integrated with the central eHealth database |

**What the adapter does:** accepts the file, validates it against the FHIR R4 schema, normalises structure (NSZU-specific extensions → standard FHIR elements where possible), imports it into the local store.

#### Source B — Estonia Digilugu

| Parameter | Value |
|----------|----------|
| Data holder | Estonian Health and Welfare Information Systems Centre (TEHIK) |
| Export format | HL7 FHIR R4 (via ENA — Estonian National Adapter), CDA for legacy records |
| How to obtain | digilugu.ee → authorisation via ID-card/Mobile-ID/Smart-ID → My data → Export |
| Authorisation | Estonian eID |
| Regulatory basis | Estonian Personal Data Protection Act + EHDS Art. 3 (right to access) |
| Technical caveats | The most mature of the EU e-health systems; clean FHIR bundles; well documented; serves as a reference example |

**What the adapter does:** accepts the file, validates it, handles the CDA→FHIR conversion for legacy records, imports.

#### Source C — Apple Health

| Parameter | Value |
|----------|----------|
| Data holder | The user themselves (Apple is processor, not controller) |
| Export format | XML (Apple's native export) + optionally FHIR (via iOS 16+ Health Records → Export to FHIR) |
| How to obtain | iPhone → Health app → Profile → Export All Health Data → ZIP file |
| Authorisation | Face ID/Touch ID/passcode on the user's device |
| Regulatory basis | Apple Privacy Policy + GDPR (Apple is obliged to provide portability) |
| Technical caveats | The XML format is not natively FHIR-compatible — conversion is required; FHIR export is available only for records obtained from FHIR-compatible providers (US Health Records integration) |

**What the adapter does:** accepts the ZIP, unpacks it, converts Apple Health XML into FHIR Observation/Condition resources, validates, imports.

### 2.2. Phase 2 (stretch / post-main-grant)

| Source | Format | Method | Complexity |
|---------|--------|--------|------------|
| Google Health Connect (Android) | Custom data classes → FHIR convert | Android export intent | Medium |
| Germany ePA (elektronische Patientenakte) | IHE XDS / FHIR (from 2025) | gematik portal with GesundheitsID | High (regulator-heavy) |
| France Mon Espace Santé | FHIR-based | DMP portal | Medium |
| Poland IKP (Internetowe Konto Pacjenta) | HL7 CDA → FHIR convert | pacjent.gov.pl | Medium |
| Generic SMART-on-FHIR (live API) | FHIR via OAuth | Per-provider login | High (per-provider) |
| Garmin / Fitbit / Withings | Vendor JSON → FHIR convert | Vendor data export | Low-medium |

### 2.3. What the project does NOT do with sources

- **Does not implement portal scraping.** If a source has no official export, we do not write a client that logs in and exfiltrates the data. That is legally and ethically dangerous.
- **Does not store source credentials.** The adapter never receives the user's login/password to an external system. The user logs in themselves, downloads themselves, brings the file in themselves.
- **Does not aggregate data across users.** Each instance sees only its own data. There is no cross-user analytics, because there is no cross-user anything.

---

## 3. Detailed flows (sequence diagrams in textual form)

### 3.1. Flow A — data import (one-time per source)

```
[User]            [UI client]       [Importer]      [Local store]
    │                  │                  │                 │
    │ 1. Goes to       │                  │                 │
    │ digilugu.ee,     │                  │                 │
    │ authenticates,   │                  │                 │
    │ downloads        │                  │                 │
    │ bundle.json      │                  │                 │
    │                  │                  │                 │
    │ 2. Opens the     │                  │                 │
    │ MyHealth-Europe  │                  │                 │
    │ UI               │                  │                 │
    │ → Import data    │                  │                 │
    │ → upload file   ─►│                 │                 │
    │                  │ 3. Hands the file│                 │
    │                  │ to the EE adapter►│                │
    │                  │                  │ 4. Validate    │
    │                  │                  │    FHIR R4     │
    │                  │                  │    schema      │
    │                  │                  │ 5. Normalise   │
    │                  │                  │    EE-extensions│
    │                  │                  │ 6. AES-GCM     │
    │                  │                  │    encrypts    │
    │                  │                  │    each record ─►│
    │                  │                  │                 │ 7. Stores
    │                  │                  │ ◄── ack ────── │   in SQLite
    │                  │ ◄── summary ─── │                 │
    │ ◄── "Imported    │                  │                 │
    │     245 records,│                   │                 │
    │     12 cat."  ── │                  │                 │
    │                  │                  │                 │
    │                  │            Audit log:              │
    │                  │            "IMPORT source=EE       │
    │                  │             count=245 at <ts>"     │
```

**What leaves the user's environment at this stage:** **nothing**. This is a 100% local operation.

### 3.2. Flow B — AI agent requests access (each session)

```
[AI agent]        [MCP server]       [Consent gateway]    [User UI]      [Local store]
    │                  │                    │                  │                 │
    │ 1. mcp/initialize│                    │                  │                 │
    │ + list_tools  ──►│                    │                  │                 │
    │                  │ ◄── tools[]: ───── │                  │                 │
    │                  │ get_observations,                     │                 │
    │                  │ get_conditions,                       │                 │
    │                  │ get_medications, ...                  │                 │
    │                  │                                       │                 │
    │ 2. tool_call:    │                    │                  │                 │
    │ get_observations │                    │                  │                 │
    │ scope:           │                    │                  │                 │
    │   {category:"lab",                    │                  │                 │
    │    date>=2025-01}│                    │                  │                 │
    │              ──► │                                       │                 │
    │                  │ 3. Checks: is     │                  │                 │
    │                  │ there a valid     │                  │                 │
    │                  │ token for this    │                  │                 │
    │                  │ scope? No.     ──►│                                    │
    │                  │                    │ 4. Asks for      │                 │
    │                  │                    │ confirmation ──►│                 │
    │                  │                    │                  │ 5. Shows the   │
    │                  │                    │                  │ user:           │
    │                  │                    │                  │ "Claude wants   │
    │                  │                    │                  │ to read lab     │
    │                  │                    │                  │ records from    │
    │                  │                    │                  │ 2025. Confirm?  │
    │                  │                    │                  │ [Yes 1h] [No]"  │
    │                  │                    │                  │                 │
    │                  │                    │ ◄── "Yes 1h" ── │                 │
    │                  │                    │                                    │
    │                  │                    │ 6. Issues token  │                 │
    │                  │                    │ scope=lab,       │                 │
    │                  │                    │ exp=now+1h,      │                 │
    │                  │                    │ audit_id=abc123  │                 │
    │                  │ ◄────────────── ─ │                                    │
    │                  │                    │                                    │
    │                  │ 7. Reads from store│                                   │
    │                  │ records in scope  │                                    │
    │                  │            ─────────────────────────────────────────►  │
    │                  │ ◄── 47 obs ─── ──────────────────────────────────── │
    │                  │                                                        │
    │ ◄── 47 lab obs   │                                                        │
    │     (JSON)    ── │                                                        │
    │                  │                                                        │
    │                  │            Audit log:                                  │
    │                  │            "READ agent=claude-desktop                  │
    │                  │             scope=lab count=47                         │
    │                  │             token=abc123 ts=<ts>"                      │
```

**What leaves the user's environment:** 47 laboratory observations are passed to the AI agent, which runs on the same machine (or in a trusted environment — for example, Claude Desktop on the same laptop). If the user has themselves chosen an agent that runs on a remote server (Claude API, OpenAI API), then the data goes there — **but that is a conscious decision by the user, not an architectural obligation on our side**.

### 3.3. Flow C — user revokes access

```
[User]            [UI client]       [Consent gateway]    [Audit log]
    │                  │                    │                  │
    │ 1. UI →          │                    │                  │
    │ Active sessions  │                    │                  │
    │              ──► │                    │                  │
    │                  │ 2. list_active  ──►│                  │
    │                  │ ◄── [claude:lab, ─ │                  │
    │                  │      llama:meds]   │                  │
    │ ◄── list ─────── │                                       │
    │                  │                                       │
    │ 2. "Revoke       │                    │                  │
    │ claude"       ──►│                    │                  │
    │                  │ 3. revoke(claude)─►│                  │
    │                  │                    │ 4. Invalidates   │
    │                  │                    │ tokens           │
    │                  │                    │ + log event ──► │
    │                  │ ◄── ack ────────── │                  │
    │ ◄── "Access      │                                       │
    │     revoked"     │                                       │
```

The agent's next request → 401 unauthorized → fresh consent prompt.

---

## 4. Trust boundaries

```
ZONE 1: On the user's device (HIGHEST TRUST)
   ├── MCP server process
   ├── UI client (browser → localhost)
   ├── Local store (encrypted SQLite)
   ├── Audit log (append-only)
   └── Consent gateway

ZONE 2: On the same device, but a different process (MEDIUM TRUST)
   └── AI agent (Claude Desktop, local Llama)
        Trust assumption: the user chose it themselves, installed it themselves.
        Receives only what has passed through the consent gateway.

ZONE 3: Remote AI services (USER-CHOSEN TRUST)
   └── Claude API, OpenAI API, EU-hosted Mistral
        Trust assumption: ONLY IF the user has consciously chosen this.
        We cannot control what happens there.
        All we can do is warn in the UI ("this model is
        cloud-based, the data will go to server X").

ZONE 4: External health sources (PRE-IMPORT, NO TRUST FROM US)
   └── eHealth UA, Digilugu, Apple Health
        We interact with them ONLY through files
        brought in by the user. No automatic
        calls from our system.

ZONE 5: The project team and anyone outside the user (ZERO TRUST = ZERO ACCESS)
   └── Hryban R., NLnet, Anthropic, downstream implementers
        Have no access whatsoever to the data of any instance.
        Architecturally impossible — not a lifestyle choice.
```

---

## 5. Audit log (a structured record of every touch on the data)

### 5.1. What is logged

Each of the following actions creates an immutable record in the local audit log:

| Event | Fields |
|-------|------|
| `IMPORT` | timestamp, source (UA/EE/Apple), count_by_resource_type, file_hash, importer_version |
| `CONSENT_GRANTED` | timestamp, agent_id, scope, ttl, audit_id |
| `CONSENT_DENIED` | timestamp, agent_id, scope_requested |
| `CONSENT_REVOKED` | timestamp, agent_id, audit_id, revoked_by |
| `READ` | timestamp, agent_id, audit_id, scope, count_returned, resource_types |
| `EXPORT` | timestamp, target_format, count, user_initiated=true |
| `DELETE` | timestamp, resource_type, count, reason |

### 5.2. Properties of the audit log

- **Append-only** — records are not edited after creation.
- **Local** — lives on the same device as the store.
- **The user is the owner** — the UI allows viewing and exporting, but not editing.
- **AI Act compliance** — the format is structured to satisfy transparency requirements for AI access to high-risk personal data.
- **GDPR Art. 30** — on request the user can export the entire log as evidence of processing activities (if needed for a DSAR).

---

## 6. What does NOT exist in our system (explicit architectural no-gos)

This section exists specifically for the committee — to leave no room for doubt.

- **There is no project backend.** On Hryban's/the team's side there is no server that would have an endpoint of the form `griban.dev/projects/myhealth-europe/api/upload`. The project URL `https://griban.dev/projects/myhealth-europe/` will only be a static site (documentation + downloads of binaries/code) as a sub-path on the applicant's existing developer domain.
- **There is no telemetry by default.** If opt-in error reporting (Sentry or self-hosted GlitchTip) appears in phase 2, it will be:
  (a) disabled by default,
  (b) limited to stack traces without user data,
  (c) pseudonymised,
  (d) fully documented.
- **There is no cross-instance analytics.** We do not know how many people use the software, beyond the count of GitHub clones and release downloads.
- **There is no update channel that could push code.** Updates are an ordinary git pull / docker pull, initiated by the user.
- **There is no key escrow.** Encryption keys are generated locally and never leave the device. If the user loses their passphrase, they lose their data (recovery is impossible from our side, and that is by design).
- **There is no cloud default.** Self-hosting in the cloud (for example, via docker compose on the user's VPS) — supported, but it is a separate, conscious choice, not the default.

---

## 7. What this means for the NLnet/NGI committee

The NGI Commons Fund evaluates against the criteria of **excellence / impact-relevance-strategic / value-for-money**. The data flow described above directly addresses two of the strategic-relevance criteria:

1. **Internet as a commons.** No component of the architecture requires a centralised intermediary. Every user is a full participant, not a client of someone else's service. That is exactly what a commons looks like at the technical level.
2. **User agency.** The user is controller, processor, key holder, and audit subject. The architecture operationalises EHDS rights at the level of the individual.

**One-paragraph answer to the question "where does the data come from", for a pitch to the committee:**

> The data never reaches us. Every EU citizen already has the right to download their medical records from their national e-health system in HL7 FHIR format — that is guaranteed to them by the EU Health Data Space Regulation. MyHealth-Europe is software that the citizen runs on their own device. They bring in their file, the program imports it into its own local encrypted store, and through the Model Context Protocol standard provides an AI agent with controlled access. The project team has neither a backend, nor an API, nor any technical channel whatsoever through which it could see user data. That is an architectural fact, not a policy.

---

*See also: [04-user-flow.md](04-user-flow.md) for detailed user journeys; [06-architecture.md](06-architecture.md) for the component decomposition; [08-threat-model.md](08-threat-model.md) for the STRIDE analysis.*
