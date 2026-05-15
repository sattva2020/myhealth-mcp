# 04 — User Flow

**Document:** MyHealth-Europe — user scenarios and journey maps
**Version:** 0.1
**Date:** 2026-05-12
**Owner:** Ruslan Hryban
**Purpose:** description of how a real EU citizen interacts with the system from first contact through to everyday use.

---

## TL;DR (for the review committee)

The user goes through five phases: (A) discovery and installation, (B) first data import, (C) connecting an AI agent and configuring trust, (D) everyday use, (E) maintenance / migration / opt-out. Each phase is designed so that the user always understands where their data lives, who has access to it, and how to revoke that access. The key design principle is **"No surprises"**: every time something crosses a trust boundary, the user explicitly authorises it and is later able to review the history.

The hardest UX challenge is to explain to a non-specialist the difference between a local AI agent (Claude Desktop, local Llama) and cloud AI (Claude API, OpenAI). The UI does this through colour coding (green / yellow) and explicit warnings of the form "this data will go to server X".

---

## 1. Personas (in more detail than in the PRD)

### Persona A — Anna, IT analyst, expat in Berlin (34)
- **Technical proficiency:** high (can use Docker).
- **Motivation:** has 5 years of Ukrainian medical history + 3 years of German. Wants to ask an English-speaking AI "when did I last get a Pap smear", because the German clinic is asking and she does not remember.
- **Barriers:** does not trust Apple Health (because Apple). Does not trust Google. Wants control.

### Persona B — Johann, retiree, Munich ↔ Alicante (71)
- **Technical proficiency:** low (smartphone, basic PC).
- **Motivation:** has DE prescriptions (5 medications) and ES prescriptions (3 medications). Worries about interactions. The doctor in Munich does not see the Spanish data.
- **Barriers:** will not install Docker. Needs a simple installer. May need help from a granddaughter.

### Persona C — Olga, nurse from Estonia with a chronic condition (42)
- **Technical proficiency:** medium (active Digilugu user).
- **Motivation:** wants to ask an AI about her condition confidentially. Does not want the queries to go to the cloud. Interested in Llama locally.
- **Barriers:** limited choice of local models with medical competence.

### Persona D — Dmytro, refugee from Kharkiv in Warsaw (28)
- **Technical proficiency:** medium.
- **Motivation:** has a UA history (eHealth Ukraine), is starting a Polish one (IKP). Does not speak Polish fluently. Wants an AI that will help him understand Polish lab results in the context of his UA history.
- **Barriers:** has no Polish ID card → limited access to IKP.

---

## 2. Phase A — discovery and installation

### A.1. Touchpoint: the user finds the project

Channels:
- A Hacker News / r/selfhosted / r/privacy post.
- An EU digital-rights newsletter (EFF EU, EDRi).
- Ukrainian/Estonian/Polish media on health-tech.
- Via HealBot.pro (reference deployment) → the user learns about upstream.
- Via DG SANTE EHDS implementation pages (if it becomes a reference tool).

### A.2. Touchpoint: landing page `griban.dev/projects/myhealth-europe/`

What they see:
- A one-screen value proposition: "your medical history, your AI assistants, your rules".
- 3 use cases in the form of short stories (based on the personas).
- An honest warning: "this is a self-hosting tool. Technical level — like setting up a home router".
- Buttons: "Download for laptop", "Run on home server (Docker)", "Source on GitHub".
- A link to the detailed documentation.

### A.3. Touchpoint: installation

Three paths, from the simplest to the advanced:

**A.3.1. Native installer (for persona B — Johann)**
- Downloads `MyHealth-Europe-Setup-1.0.exe` (Windows), `.dmg` (macOS), `.AppImage` (Linux).
- The installer is robotic: passphrase setup → finish.
- Launches in the tray, the browser auto-opens at `http://localhost:7777`.

**A.3.2. Docker compose (for persona A — Anna, persona C — Olga)**
```bash
curl -O https://griban.dev/projects/myhealth-europe/docker-compose.yml
docker compose up -d
open http://localhost:7777
```

**A.3.3. From source (for downstream developers, audit)**
```bash
git clone https://github.com/myhealth-europe/myhealth-europe
cd myhealth-europe
just setup && just run
```

### A.4. Touchpoint: initial setup (setup wizard)

Steps in the wizard:
1. **Welcome screen** — explanation of what is about to happen, in the interface language (defaults to the system locale; explicit switcher).
2. **Privacy explainer** — half a screen of explanation that no data leaves without explicit permission; a link to the detailed `03-data-flow.md`.
3. **Passphrase setup** — minimum 12 characters, perfect-passphrase suggestion (4-6 random words); the warning "we CANNOT recover it — that is by design".
4. **Recovery file** — the wizard offers to generate a recovery file (an encrypted backup of the key); the user themselves places it in a safe location (USB stick, sealed banking envelope, password manager).
5. **Locale** — interface language, language of medical records (they may differ).
6. **First import** — offers to import immediately; or skip.

---

## 3. Phase B — first data import

### B.1. The user chooses a source

The UI shows a list of supported sources with flags and a short description:
- 🇺🇦 eHealth Ukraine — "export from helsi.me or the NHSU patient cabinet"
- 🇪🇪 Estonia Digilugu — "export from digilugu.ee → My Data"
- 🍎 Apple Health — "Settings → Health → Export All"
- (more — phase 2)

Next to each — a "How to export from here" button with step-by-step screenshots.

### B.2. The user obtains the file

Depending on the persona:

**Persona A (Anna, for UA):**
1. Goes to helsi.me, authenticates with BankID or Diia.
2. In the cabinet → My data → Download medical history → receives `medical-history.json`.

**Persona C (Olga, for EE):**
1. Goes to digilugu.ee, authenticates with Mobile-ID.
2. Minu andmed → Eksport → `digilugu-export.json`.

**Persona D (Dmytro, for UA, working without a Polish ID):**
1. Same as Anna for the UA part.
2. For the Polish part — Dmytro obtains a temporary PESEL through the CUW and later tries IKP (phase 2).

### B.3. Import into MyHealth-Europe

```
UI → Import data → drag-and-drop the file
   ↓
Detect: "this looks like digilugu-export.json. Import as EE? [Yes/No/Manual]"
   ↓
Validation: "245 records valid, 0 errors, 2 warnings (legacy CDA → FHIR conversion)"
   ↓
Show summary table:
   ┌──────────────────┬───────┬──────────────────┐
   │ Resource type    │ Count │ Date range       │
   ├──────────────────┼───────┼──────────────────┤
   │ Observation      │ 156   │ 2018-03 – 2026-04│
   │ Condition        │ 23    │ 2019-01 – 2024-11│
   │ MedicationRequest│ 47    │ 2020-06 – 2026-05│
   │ Encounter        │ 19    │ 2018-03 – 2026-04│
   └──────────────────┴───────┴──────────────────┘
   ↓
[Import] → progress bar → done
```

### B.4. What the user does next

The UI suggests next steps:
- "Import another source" (for persona A — Anna, who now imports DE ePA).
- "View my records".
- "Connect an AI agent" (the next phase).

---

## 4. Phase C — connecting an AI agent and configuring trust

### C.1. The user chooses an agent

The UI shows a matrix of options with colour coding:

| Agent | Where it lives | Where the data goes | Trust level |
|-------|---------|-----------------|-------------|
| Claude Desktop (local install) | Local process | Anthropic API (cloud) | 🟡 yellow |
| OpenAI ChatGPT Desktop | Local process | OpenAI API (cloud) | 🟡 yellow |
| Llama (Ollama locally) | Local process | Nowhere | 🟢 green |
| EU-hosted Mistral | Local client | Mistral EU servers | 🟡 yellow (EU) |
| Custom MCP client | Per-config | Per-config | ⚪ unknown |

Next to each — an explanation in plain language. Yellow ≠ bad — it means "you are consciously sharing with the cloud".

### C.2. Connecting Claude Desktop (example for persona A)

1. In Claude Desktop → Settings → MCP Servers → Add server.
2. Or copy-paste from the MyHealth-Europe UI ("Click to copy Claude config").
3. Config:
   ```json
   {
     "mcpServers": {
       "myhealth-europe": {
         "command": "myhealth",
         "args": ["mcp-server", "--stdio"]
       }
     }
   }
   ```
4. Restart Claude Desktop.
5. The tools `get_observations`, `get_medications`, etc., are now available in Claude.

### C.3. The first AI session — consent flow

```
[Anna in Claude:] "I don't remember when I had a Pap smear. Can you find it?"

[Claude:] (wants to call get_observations(category=exam, code=pap-smear))
          Requests permission via MCP → MyHealth-Europe consent gateway

[MyHealth-Europe UI (notification):]
   ┌────────────────────────────────────────────────────────┐
   │ Claude Desktop is requesting:                          │
   │                                                         │
   │ Read: Observations                                     │
   │ Category: examination                                  │
   │ Filter: pap-smear, all dates                          │
   │                                                         │
   │ Trust level: 🟡 cloud (data will go to anthropic.com) │
   │                                                         │
   │ [Allow for 5 min] [For 1 h] [For 24 h] [No]          │
   │                                                         │
   │ ☐ Remember this choice for similar requests           │
   └────────────────────────────────────────────────────────┘

[Anna clicks "For 5 min"]

[Claude receives a token → reads 2 results → forms a response]
[Claude:] "Last Pap smear — 2024-09-12, at clinic X in Berlin.
           Previous one — 2023-03-15 in Kyiv. According to the ESGO
           recommendations, the next one is due 2027-09 (3-year interval
           for normal results)."

[Anna — in the MyHealth-Europe UI:]
   Audit log shows: READ at 14:32, scope=examination:pap-smear,
   agent=claude-desktop, count=2, token expires 14:37
```

### C.4. Configuring "persistent" permissions

For repeated requests the user can configure a persistent grant:
- Scope: medication list (excluding psych meds)
- TTL: 30 days
- Agent: Llama local
- Conditions: only on this device

This is done in the UI → Sessions → New persistent grant.

---

## 5. Phase D — everyday use

### D.1. Use case: routine question
Anna → Claude → "What is my latest HbA1c?" → consent prompt (because of a new scope) → 1-hour permission → answer.

### D.2. Use case: cross-border continuity (for persona B — Johann)
Johann before a trip to Alicante:
1. Imports his German ePA data.
2. Asks: "Prepare a summary for the Spanish doctor in Spanish".
3. The agent → requests scope `read:all` for 30 minutes → Johann allows it → the agent generates a PDF.
4. Johann prints the PDF and takes it with him.

### D.3. Use case: medication reconciliation
Johann:
1. Imports both sets (DE + ES).
2. Asks: "Are there any interactions between my DE and ES prescriptions?"
3. The agent → queries medications → calls a drug interaction DB → answer.

### D.4. Use case: privacy-conscious offline
Olga:
1. Runs Llama locally (Ollama).
2. Connects it to MyHealth-Europe.
3. Asks — everything happens offline. The audit log shows `agent=ollama-local`, trust=🟢.

### D.5. Use case: a new doctor in Poland
Dmytro:
1. Imports his UA history.
2. Before the first visit to a Polish therapist, generates a PDF with the main diagnoses/prescriptions in Polish.
3. Prints it. Brings it with him.

### D.6. Recurring touchpoints
- Periodic re-import (once a quarter — new records from the source).
- Reviewing the audit log (once a month — who has been reading).
- Revoking stale grants (the UI flags grants older than 90 days and offers to revoke them).

---

## 6. Phase E — maintenance, migration, opt-out

### E.1. Backup
```bash
myhealth backup --out ~/Documents/myhealth-backup-2026-05-12.enc
```
or UI → Settings → Backup → asks where to save it. The backup is encrypted with the same key; recoverable only with the passphrase + recovery file.

### E.2. Moving to a new device
1. On the new device — install + setup wizard.
2. At the "Initial passphrase" step — choose "Restore from backup".
3. Upload the backup file + enter the passphrase + recovery file.
4. The data is restored; the agents need to be re-configured (consent grants are per-device for security).

### E.3. Deleting data
- UI → Settings → Danger zone → Delete all data.
- Confirmation by typing "DELETE EVERYTHING".
- Data is soft-deleted for 30 days (recoverable).
- After 30 days — hard delete + audit record.

### E.4. Exporting everything for another tool
```bash
myhealth export --format fhir-bundle --out ~/my-data-bundle.json
```
A standard FHIR R4 bundle, transferable into any FHIR-compatible service. This is GDPR Art. 20 portability.

### E.5. Opting out of the project (offboarding)
- The user exports the data as in E.4.
- Deletes the application.
- That's it. No residue on the project side (because there was none to begin with).

### E.6. What if the user loses their passphrase
- If they have a recovery file — use it to unlock.
- If there is no recovery file — the data is lost. By design. This is warned about in the setup wizard in three places.
- Alternative: re-import from the sources (the data does sit in the original sources).

---

## 7. Cross-cutting states and edge cases

| Scenario | Behaviour |
|----------|-----------|
| The user imports a file with invalid FHIR | The valid records are imported partially; the others are quarantined with a stated reason |
| Importing the same file twice | Idempotent — no duplication |
| The user wants to import "from a second country" | Each source is a separate import; the records do not get mixed up |
| Two instances on a single PC (e.g. for family members) | Supported via a `--config` flag with different passphrases; isolated stores |
| Children's data (parent imports for the child) | Out of scope in phase 1; an explicit warning "use a separate instance per person" |
| Smartphone-only user | Out of scope in phase 1 (a mobile-native client is phase 2). Workaround: a mobile browser pointed at a self-hosted instance on a NAS |
| The AI agent asks for too much scope | The consent UI explicitly indicates how much data will be exposed; the user can manually narrow the scope |
| The audit log overflows | Rotation by TTL (default: 2 years); export before rotation as CSV |

---

## 8. UX metrics (for validation in M6)

| Metric | How we measure | Target |
|---------|-----------|---------|
| Time-to-first-import | From install to first import | <15 min median in n=10 user test |
| Consent comprehension | Whether the user understands what they are consenting to | ≥80% correct answers in follow-up interview |
| Trust-level differentiation | Whether they distinguish local vs. cloud AI | ≥80% in follow-up |
| Task success | Whether they can complete "find the latest HbA1c" | ≥80% without assistance |
| SUS score (System Usability Scale) | Standard SUS questionnaire | ≥70 (above average) |

---

*See: [03-data-flow.md](03-data-flow.md) for the technical detail of what moves around; [06-architecture.md](06-architecture.md) for the components that implement these flows.*
