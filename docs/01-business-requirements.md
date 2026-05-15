# 01 — Business Requirements Document (BRD)

**Document:** MyHealth-Europe — business requirements
**Version:** 0.1 (initial draft)
**Date:** 2026-05-12
**Owner:** Ruslan Hryban, Project Lead
**Status:** internal draft, pending team review

---

## TL;DR (for the review committee / non-technical readers)

EU citizens are legally entitled to their medical data (since March 2025, under the EU Health Data Space Regulation, EHDS), but in practice they cannot use that right the way they want to: bringing any AI assistant to their data on their own terms. The data is scattered across vendor silos (Apple, Google, Epic, national portals), AI assistants are tied to whoever owns the data, and there is no standard consent flow for AI access.

MyHealth-Europe solves this problem: it is open-source software that every citizen deploys on their own device, imports their FHIR records from existing sources, and through the open Model Context Protocol (MCP) grants any AI agent controlled access. The project team never touches user data — that is an architectural property, not a policy one.

**Business outcome at 9 months:** a working, audited MCP server adopted by at least 3 independent downstream projects, with a cross-border health-navigation pilot in one EU country.

**Long-term business outcome:** the first canonical open-source MCP server for health, embedded in the regulatory environment of EHDS and the AI Act, ready for adoption by EU member states.

---

## 1. Problem context

### 1.1. Structural problem (level 1 — the user)

An ordinary EU citizen in 2026 faces three simultaneous challenges:

**Challenge A: Data lock-in.** Medical records are fragmented across dozens of systems — national e-health systems (eHealth Ukraine, Estonia Digilugu, France Mon Espace Santé, Germany ePA), hospital portals (Epic MyChart, Cerner, national equivalents), wearables (Apple Health, Google Health Connect, Fitbit, Garmin), insurance companies, pharmacies. Each endpoint exports data in its own way, in different formats, with varying degrees of completeness. The FHIR standard has been adopted on paper, but real interoperability is patchy.

**Challenge B: AI-assistant lock-in.** When a vendor offers AI on top of health data (Apple Intelligence, Google Med-PaLM, Epic GPT integrations), that AI is bound to the vendor's infrastructure and model. The user cannot substitute another model — not even a local one. The "intelligence layer" is captured by whoever owns the data.

**Challenge C: No consent standard for AI.** OAuth gives applications access to APIs. SMART on FHIR gives clinical apps access to records. But there is no widely-deployed standard for the specific case of "an AI agent reads my data with this scope, for this period, with an audit log and explicit revocation."

### 1.2. Structural problem (level 2 — the state and the regulator)

In 2025 the EU adopted two regulatory instruments that created a right but did not operationalise it:

- **The EHDS Regulation** (in force since March 2025) gives citizens the right to digital access to their health data and the right to share it with a chosen recipient. In practice, every member state implements this in its own way, without a shared end-user tool.
- **The AI Act, Article 50** requires transparency for AI in high-risk domains. Who and when granted an AI agent access to medical data? How is this audited? There is no tool.

Without an operational layer at the level of the citizen themselves, both regulations remain declarations.

### 1.3. Cross-border context (unique to the EU)

The EU is 27 separate national health systems plus associated countries. Every day moving across them are:

- Millions of expat workers, who receive treatment in one country while living in another.
- Around 4 million Ukrainian refugees in EU countries (as of 2026), with medical history in two or three systems at once.
- Tourists receiving treatment abroad.
- Medical retirees with cross-border treatment.

No single national system can solve this problem — it requires a tool *above* national systems that runs on the user's own device.

---

## 2. Target audience

### 2.1. Primary — end user (individual citizen)

**Who:** any resident of the EU or an associated country who has medical history in more than one source and wants to safely use an AI assistant.

**Size:** TAM ~500+ million people (all EU residents). SAM for the first phase — the cross-border cohort (~30-50 million people): expats, refugees, digital nomads, tourists with chronic conditions.

**Technical literacy:** the expected spectrum runs from "I can run a Docker container" to "I can click inst.exe". The reference UI client targets the lower bar; CLI/Docker the upper.

**First 1000 users (early adopters):** technically literate, privacy-conscious, active in open-source / Mastodon / EU digital-rights circles.

### 2.2. Secondary — downstream adopters

**Who:** developers, integrators, digital-government teams, telemedicine startups, research groups, digital cooperatives (for example, MiData in Switzerland, the Solid pods community).

**Size:** ~10-50 team adoptions in the first year (the consortium target under the grant is 3 downstream projects, but the real ambition is higher).

**What they want:** a reference implementation on which to build a localised version — a national health cooperative, a research tool, a specialised clinical agent.

### 2.3. Tertiary — regulators and policymakers

**Who:** EHDS implementation teams in each member state, national data protection authorities, DG SANTE, DG CONNECT.

**What they want:** a working example of how EHDS rights are operationalised at the citizen level, with an audit log fit for AI Act compliance.

---

## 3. Project goals

### 3.1. Business goals (9 months, within NGI Commons Fund)

| ID | Goal | Metric | Target |
|----|------|--------|--------|
| G1 | Publish MCP server v1.0 | GitHub/Codeberg release, signed tag | By end of M9 |
| G2 | Pass an independent security audit | Public report; all medium+ findings closed | By end of M8 |
| G3 | Adoption (downstream) | Number of independent deployments | ≥3 within 12 months after M9 |
| G4 | Reference pilot | End-to-end demo in one EU country | By end of M7 |
| G5 | Standards engagement | Participation in MCP working group / FHIR community | ≥1 PR accepted into MCP spec, ≥1 speaker slot at an EU event |

### 3.2. Strategic goals (24-36 months)

| ID | Goal | What success looks like |
|----|------|--------------------------|
| S1 | MyHealth-Europe — Module No. 1 in CivicAI Bridge | DIGITAL-2027-AI proposal submitted with MyHealth-Europe as a working module proof |
| S2 | Adoption by at least one national e-health authority | Pilot or production deployment in EE/PL/DE/NL e-health |
| S3 | Canonical MCP server for health data | Mentioned in MCP documentation / specification as a reference |
| S4 | EHDS implementation tool | At least one member state cites MyHealth-Europe in its EHDS implementation plan |

### 3.3. Non-goals (explicitly out of scope)

- **Not a clinical tool.** Does not provide diagnoses, does not prescribe treatment. It is a data layer.
- **Not a replacement for national e-health.** Does not attempt to replace eHealth Ukraine, Digilugu, or ePA. It complements them, as a layer on top.
- **Not a commercial SaaS in the initial release.** If somebody wants to build managed hosting on top of the core, that is their right (Apache 2.0 permits it), but we ourselves will not run a SaaS within the project.
- **Not an EHR replacement for clinics.** It is user-side, not provider-side.

---

## 4. Scope and constraints

### 4.1. Phase 1 scope (current grant, 9 months)

**Included:**
- MCP server core (read-only tools surface).
- FHIR adapters for 3 sources: eHealth Ukraine, Estonia Digilugu, Apple Health.
- OAuth 2.1 consent gateway with scope-by-record-type and time-bound tokens.
- Audit log (structured, local).
- Reference UI client (self-hosted web).
- Reference cross-border navigation agent (UA-EE pilot).
- Security audit and remediation.
- Documentation and replication kit.

**Excluded from phase 1 (stretch / later phases):**
- Write-back to sources (writing new records into a portal).
- Live API connectors (rather than bulk export) for sources that support them.
- Native mobile client (Android/iOS app).
- Adapters beyond the 3 planned (Poland, Germany, France, Google Health Connect — phase 2).
- Cluster deployment for organisations (phase 1 ships single-user instances only).

### 4.2. Regulatory constraints

- **GDPR.** Although the project architecturally minimises processing (the user is both controller and processor in self-hosted mode), components that touch logs and metadata must comply with GDPR on the side of downstream adopters.
- **EHDS.** Adapters must respect EHDS-compatible export formats.
- **AI Act Art. 50.** The audit log is structured to satisfy transparency requirements for AI access.
- **Ukrainian legislation.** The applicant is a resident of Ukraine; for the UA side the project takes into account the Law "On the Protection of Personal Data" and the patient's right to obtain medical information (Law "Fundamentals of the Healthcare Legislation", Article 39).

### 4.3. Resource constraints

- **Budget:** €50,000 lump sum (NLnet first-application cap).
- **Team:** 1 full-time engineer (R. Hryban) + 3 part-time co-founders (coordination, BD, domain advice) + 2 subcontractors (FHIR ingester, security audit).
- **Duration:** 9 months from MoU signature.
- **Infrastructure:** ~€3K for cloud / AI tooling over the whole period.

---

## 5. Success Metrics (KPI)

| Category | KPI | Baseline | M9 target | How we measure |
|----------|-----|----------|-----------|----------------|
| Code health | Test coverage | 0% | ≥80% | CI report |
| Code health | Security findings (high+) | n/a | 0 open | Audit report |
| Performance | FHIR query p99 latency | n/a | <200ms | Benchmark suite |
| Adoption | GitHub stars | 0 | ≥500 | GitHub API |
| Adoption | Independent downstream projects | 0 | ≥3 | Manual tracking |
| Standards | MCP-spec contributions | 0 | ≥1 accepted | MCP repo |
| Community | Documentation pageviews/month | 0 | ≥2000 | Plausible/GoatCounter |
| Pilot | End-to-end UA-EE scenarios passing | 0 | ≥4 (from milestone M7) | Demo scenarios |

---

## 6. Assumptions and risks (summary)

| Assumption | If it does not hold |
|------------|---------------------|
| The MCP protocol stays stable | Pin the version at M1; participate in the working group to anticipate changes |
| FHIR bulk export from UA eHealth is available without additional barriers | Start with sandbox / synthetic data; real bulk export — at M+ |
| NLnet accepts a Ukrainian sole proprietor (ФОП) as applicant | Fallback plan: TOV Kratos (Myroshnykov) as applicant |
| An Estonia/Germany pilot partner can be found | The pilot is best-effort; core deliverables do not depend on it |
| One full-time engineer is enough for 9 months of scope | Phase 1 scope is deliberately limited to 3 sources and read-only |

More detail in `06-architecture.md` (deployment risks) and `08-threat-model.md` (security risks).

---

## 7. Stakeholders and roles

| Stakeholder | Interest | How we serve them |
|-------------|----------|-------------------|
| End user | Control over their data, simplicity | Self-hosted, clear consent UI |
| NLnet/NGI | Digital commons, EU-fit | Apache 2.0, EHDS-aligned, audited |
| EHDS implementation teams | Operational tool for citizen rights | Replication kit, documentation |
| Downstream developers | A working base for forking | Clear interfaces, documented schemas |
| Independent auditor | Credible privacy claim | Threat model, public audit report |
| Grant team (4 people) | Successful grant, sustainability | The current draft plus this workspace |

---

## 8. Open business questions

1. **Sustainability post-grant.** How does the project live after 9 months? Options: a follow-on NGI proposal for phase 2 (NLnet allows it); a DIGITAL-EU grant via CivicAI Bridge; community-driven support; a managed-hosting commercial spin-off (while preserving the Apache core). Decision after M6.
2. **Legal structure for follow-on grants.** Sole proprietor (ФОП) Hryban R. for phase 1, but for phase 2 (€100K+) a TOV (LLC) may be required. Decision in M5-M6 together with Myroshnykov.
3. **Trademark / domain.** Should "MyHealth-Europe" be registered as a trademark and should we buy a dedicated domain (`myhealth-europe.eu`, `.org` or `.health`)? **Pre-award:** project URL = `https://griban.dev/projects/myhealth-europe/` (sub-path on the applicant's existing site — €0). **Post-award:** dedicated domain optional (€10-15/year), trademark — with legal advice in M2-M3 (€500-€1500 from the outreach budget).
4. **Liaison with the EU Health Data Space office.** Should we do official outreach to the DG SANTE EHDS team? If so — when and by whom. Decision: Myroshnykov + Hryban by M3.

---

*Next documents: [02-prd.md](02-prd.md) elaborates the functional and non-functional requirements; [03-data-flow.md](03-data-flow.md) provides the data-flow picture that is critical for understanding the project.*
