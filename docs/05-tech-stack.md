# 05 — Tech Stack

**Document:** MyHealth-Europe — technology stack selection
**Version:** 0.1
**Date:** 2026-05-12
**Owner:** Ruslan Hryban
**Status:** **locked in** — Rust from the very beginning (applicant decision, 2026-05-12).

---

## TL;DR (for the team and review committee)

Four realistic candidates were evaluated: **Python+FastMCP**, **TypeScript** (Node.js), **Go**, and **Rust**. Each was scored against seven criteria: MCP SDK maturity, FHIR ecosystem, deployment simplicity, performance, security baseline, learning/maintenance curve for the applicant, and fit for self-hosted health software.

**Decision adopted: Rust + `rmcp` as the primary stack from M1.** Although Python formally has the higher weighted score (4.27 versus 3.93), the qualitative analysis — deployment simplicity for the Johann persona, memory safety without GC for PHI handling, and a single static binary under 15 MB as the reference deployment for self-hosted health software — outweighed it. The project thesis ("every EU citizen should have a tool that runs without unnecessary dependencies") demands a Rust-class deployment story from day one, not as a phase 2 rewrite.

Cost of this choice: roughly 2–3 additional inception weeks (Rust scaffolding, ramp-up on `rmcp` and `fhirbolt`), a narrower FHIR ecosystem (mitigated by the fact that the FHIR R4 schema is stable — once a strong-typed parser is written, it works), and a smaller pool of potential contributors in the first year. Trade-offs covered in §6.3 below.

---

## 1. Selection context

The technology stack candidate must be chosen so that it simultaneously satisfies five constraints:

1. **Development team — 1 engineer (R. Hryban) over 6 PM** with the option of a part-time contributor on the FHIR ingester (2 PM). The stack must be productive at this team size.
2. **Open-source community and downstream adoption.** The stack must be accessible to contributors and not block adoption through exoticism.
3. **Self-hosting** across multiple targets: Linux x86/ARM (including Raspberry Pi 4), macOS, Windows, and Docker.
4. **Health-domain ecosystem:** FHIR parsers and validators, healthcare standard support.
5. **Security baseline:** memory safety, supply chain hygiene, audit-friendliness.

Decision window: before the start of M1 (anticipated Q3 2026). This document appears pre-grant; the decision is made at team review after the grant award.

---

## 2. Evaluation criteria

| # | Criterion | Weight | Why it matters |
|---|-----------|--------|----------------|
| C1 | MCP SDK maturity | 0.20 | MCP is the heart of the project. A mature SDK = less bugfixing of native code. |
| C2 | FHIR / health ecosystem | 0.18 | Saves weeks on parsers, validators, R4 schema. |
| C3 | Deployment simplicity for the end user | 0.15 | The Johann persona is the limiting factor. Single binary > Docker > runtime. |
| C4 | Performance and resource footprint | 0.12 | Raspberry Pi 4 is a target. p99 < 200 ms is a requirement. |
| C5 | Security baseline (memory safety, supply chain) | 0.15 | Health software with PHI = high stakes. |
| C6 | Productivity for the applicant (learning curve, maintenance) | 0.12 | 1 engineer × 6 PM leaves no buffer for a large-scale learning effort. |
| C7 | Open-source adoption / contributor accessibility | 0.08 | Apache 2.0 + adoption is part of the value proposition. |

Scale: 1 (poor) — 5 (excellent).

---

## 3. Candidate 1: Python + FastMCP

### 3.1. What it is

- **Python 3.12+**.
- **FastMCP** ([github.com/jlowin/fastmcp](https://github.com/jlowin/fastmcp) — community-driven, or the official `mcp` Python SDK from Anthropic).
- FHIR ecosystem: `fhir.resources` (Pydantic-based FHIR R4/R5 models), `fhirpathpy`, `hl7apy` for legacy HL7v2.
- Web framework for the UI backend: FastAPI.
- Storage: SQLAlchemy + SQLite (with `pysqlcipher3` for encryption-at-rest) or plain SQLite + per-record encryption via `cryptography`.
- OAuth: `authlib`.
- Packaging: Docker (the primary form), PyInstaller or `briefcase` for a native binary.

### 3.2. Scoring against the criteria

| Criterion | Score | Rationale |
|-----------|-------|-----------|
| C1 — MCP SDK | 5/5 | Most mature SDK; official from Anthropic; widespread practical use |
| C2 — FHIR ecosystem | 5/5 | The richest: `fhir.resources` provides full R4 + R5 coverage, `fhirpathpy`, integrations with SMART on FHIR |
| C3 — Deployment | 3/5 | Docker — fine. A native binary via PyInstaller is possible but heavier (~50–100 MB). Johann can manage via an installer wrapper |
| C4 — Performance | 3/5 | Async Python with FastAPI is sufficient for a typical case. CPU-heavy parsing of large bundles is 5–10× slower than Rust/Go. Raspberry Pi 4 is OK for modest volumes |
| C5 — Security | 3.5/5 | Memory safety is provided (GC), but the dependency tree is large → higher supply chain risk. CVE history is typical for Python ecosystems. SBOM + signed releases mitigate this |
| C6 — Productivity for the applicant | 5/5 | The applicant has 3+ years with MCP servers. Python is the primary working stack. Smallest learning curve |
| C7 — Adoption / contributors | 5/5 | Python is #1 in the health-data ecosystem. Largest pool of contributors |

**Weighted score: 0.20×5 + 0.18×5 + 0.15×3 + 0.12×3 + 0.15×3.5 + 0.12×5 + 0.08×5 = 4.27/5**

### 3.3. Pros

- The fastest possible start.
- The largest FHIR ecosystem (this is no small thing — `fhir.resources` alone saves weeks).
- The applicant is productive from day one.
- The largest potential pool of contributors.
- Reference MCP server implementations in Python are widely available.

### 3.4. Cons

- Deployment is not as clean as a native binary.
- Supply chain — more dependencies → larger attack surface.
- Performance — good but not excellent for CPU-bound FHIR parsing of large bundles.
- The earliest of the candidates to age performance-wise if the project scales to cluster deployment (phase 3+).

---

## 4. Candidate 2: TypeScript (Node.js)

### 4.1. What it is

- **Node.js 22+ LTS**, **TypeScript 5.x**.
- MCP: `@modelcontextprotocol/sdk` (Anthropic's official TS SDK).
- FHIR ecosystem: `@types/fhir`, `fhir-kit-client`, `medplum-fhir-types`. Weaker than Python.
- Web framework: Fastify or Hono.
- Storage: better-sqlite3 + cipher via application-layer encryption.
- OAuth: `oidc-provider`.
- Packaging: Docker, or `pkg` / `nexe` for a bundled executable.

### 4.2. Scoring

| Criterion | Score | Rationale |
|-----------|-------|-----------|
| C1 — MCP SDK | 5/5 | Official TS SDK; equal to Python in functionality |
| C2 — FHIR ecosystem | 3/5 | Has basic types, but parsers and validators are less mature. The Medplum ecosystem is growing, but it is client-focused |
| C3 — Deployment | 3.5/5 | Docker — fine. `pkg` produces a single binary, but with the Node runtime embedded (60–80 MB) |
| C4 — Performance | 3.5/5 | V8 is fast for I/O, but CPU-bound FHIR parsing is roughly on par with Python |
| C5 — Security | 3/5 | Memory safety is provided (V8). The npm supply chain is worse than Python's (more small dependencies, a history of incidents like `event-stream`) |
| C6 — Applicant productivity | 3.5/5 | The applicant is comfortable with TS, but it isn't the primary stack |
| C7 — Adoption | 4/5 | Large community, but smaller in the health domain |

**Weighted score: 0.20×5 + 0.18×3 + 0.15×3.5 + 0.12×3.5 + 0.15×3 + 0.12×3.5 + 0.08×4 = 3.61/5**

### 4.3. Pros

- If we want the UI client and server in a single repo/language, TS allows code-sharing of types.
- Async by default, good for concurrent agent requests.
- A large pool of contributors.

### 4.4. Cons

- Weaker FHIR ecosystem.
- npm supply chain risk.
- The applicant is less productive than in Python.

---

## 5. Candidate 3: Go

### 5.1. What it is

- **Go 1.23+**.
- MCP: `mcp-go` (community-driven, with several implementations; the official Anthropic Go SDK is still emerging as of 2026).
- FHIR ecosystem: `github.com/SamuelBoehm/fhir` (R4 models), `github.com/google/fhir` (Google, but large and complex), Bonfhir (R5).
- Web framework: standard library + chi router.
- Storage: SQLite via `mattn/go-sqlite3` + application-layer encryption.
- OAuth: `golang.org/x/oauth2`.
- Packaging: native cross-compile to a single static binary, ~10–20 MB.

### 5.2. Scoring

| Criterion | Score | Rationale |
|-----------|-------|-----------|
| C1 — MCP SDK | 3/5 | Less mature, with several competing implementations |
| C2 — FHIR ecosystem | 3/5 | Google FHIR is the major player but heavy. SamuelBoehm is simpler. Less choice |
| C3 — Deployment | 5/5 | Native single binary, cross-compile is trivial. Johann gets `myhealth.exe` and it just works |
| C4 — Performance | 4.5/5 | Fast, low memory footprint, good on ARM |
| C5 — Security | 4/5 | Memory safety (GC); supply chain is simpler (fewer dependencies in projects); good toolchain monitoring |
| C6 — Applicant productivity | 3/5 | The applicant knows Go but it isn't the primary stack |
| C7 — Adoption | 3.5/5 | Smaller pool of contributors than Python/TS |

**Weighted score: 0.20×3 + 0.18×3 + 0.15×5 + 0.12×4.5 + 0.15×4 + 0.12×3 + 0.08×3.5 = 3.62/5**

### 5.3. Pros

- The best deployment story of all the candidates.
- Fast, predictable, low resource consumption.
- A solid concurrency story for the consent gateway.

### 5.4. Cons

- Less mature MCP SDK — more risk of having to chase SDK bugs.
- A less rich FHIR ecosystem.
- The applicant is less productive.

---

## 6. Candidate 4: Rust

### 6.1. What it is

- **Rust 1.80+** (stable).
- MCP: `rmcp` ([github.com/modelcontextprotocol/rust-sdk](https://github.com/modelcontextprotocol/rust-sdk)) — official from Anthropic (since late 2024 — early but maturing rapidly). Alternative: `mcp-sdk-rs` (community).
- FHIR ecosystem: `fhirbolt` (R4/R4B/R5 strong-typed models), `fhir-r4` (alternative), `fhirpath-rs`. Younger than Python's, but it exists.
- Web framework: Axum (with the tower middleware ecosystem) or Actix-web.
- Storage: `rusqlite` + `sqlcipher` backend or application-layer `aes-gcm` crate.
- OAuth: `oauth2` crate.
- Packaging: native single static binary (with musl — fully static), ~5–15 MB. Cross-compile via cargo-zigbuild.

### 6.2. Scoring

| Criterion | Score | Rationale |
|-----------|-------|-----------|
| C1 — MCP SDK | 3.5/5 | `rmcp` is official but younger than Python/TS. Active development. Production-ready with certain caveats |
| C2 — FHIR ecosystem | 3/5 | `fhirbolt` is strong-typed and well-built, but narrower than Python's. Lacks tooling and community resources |
| C3 — Deployment | 5/5 | Native single binary, the smallest footprint of all. Johann gets a ~10 MB executable |
| C4 — Performance | 5/5 | The best of all. CPU-bound FHIR parsing is 5–10× faster than Python. Comfortable on a Raspberry Pi |
| C5 — Security | 5/5 | Memory safety without GC; the best supply chain story in systems programming (cargo audit, crev), zero-cost abstractions, audit-friendly |
| C6 — Applicant productivity | 2.5/5 | The applicant has basic familiarity with Rust but it isn't the primary stack. The learning curve adds ~3–4 weeks for production code |
| C7 — Adoption | 3/5 | Smaller pool of contributors in the health domain; Rust is loved by engineers but less plug-and-play |

**Weighted score: 0.20×3.5 + 0.18×3 + 0.15×5 + 0.12×5 + 0.15×5 + 0.12×2.5 + 0.08×3 = 3.93/5**

### 6.3. Pros

- The best deployment + performance + security mix.
- Memory safety without GC — critical for PHI-handling code (no temporary copies in the GC heap, easier to audit).
- Single static binary with the smallest footprint.
- Rust has strong adoption in the privacy-focused community (Signal protocol implementations, AGE encryption, etc.) — this aligns with the project ethos.
- A reasoning-friendly language — fewer runtime surprises, which is valuable for an audit-oriented project.

### 6.4. Cons

- Steepest learning curve of the candidates.
- The narrowest FHIR ecosystem.
- 6 PM in Rust ≈ 5 PM in Python after learning and reworks.
- Fewer available contributors.
- If a Python-only FHIR tool is needed (`smart-on-fhir` for testing) — FFI bridges or subprocesses are required.

---

## 7. Summary matrix

| Criterion (weight) | Python | TypeScript | Go | Rust |
|--------------------|--------|------------|-------|------|
| MCP SDK (0.20) | 5 | 5 | 3 | 3.5 |
| FHIR (0.18) | 5 | 3 | 3 | 3 |
| Deployment (0.15) | 3 | 3.5 | 5 | 5 |
| Performance (0.12) | 3 | 3.5 | 4.5 | 5 |
| Security (0.15) | 3.5 | 3 | 4 | 5 |
| Productivity (0.12) | 5 | 3.5 | 3 | 2.5 |
| Adoption (0.08) | 5 | 4 | 3.5 | 3 |
| **Weighted score** | **4.27** | **3.61** | **3.62** | **3.93** |

---

## 8. Decision adopted and rationale

### 8.1. Decision: Rust + `rmcp` from the very beginning (M1)

**Why Rust prevailed despite the lower weighted score:**

1. **The weighted score did not capture the architectural axis of the project thesis.** The project sells "self-hosted privacy-by-architecture" to its audience. The weakest link in that story is deployment friction. A Python deployment ("docker compose" or a "PyInstaller bundle") does not let the Johann persona (71 years old, low-tech) install the software without outside help. A Rust single static binary `myhealth.exe` (~10–15 MB) does. This is not "nice-to-have" — it is the core value proposition.

2. **Memory safety without GC** carries disproportionately large weight for health software handling PHI. An auditor reviewing the consent gateway and store at M8 can trust that Rust code has no use-after-free, double-free, or race conditions in `unsafe`-free code. That means a shorter audit report and fewer middle-severity findings that could push back the M9 release.

3. **Resource footprint matters for Raspberry Pi/NAS deployments.** The target audience includes personas running on home servers (Synology, TrueNAS). A Rust binary with 5–15 MB RAM idle versus Python with 80–100 MB is the difference between "fits inside a 2 GB Pi alongside other services" and "requires a separate device".

4. **A phase 2 rewrite is false economy.** Starting on Python with a plan to "rewrite the hot path in Rust at M5–M6" results in two parallel codebases, FFI bridges, two test sets, and two supply chains. A strategic debt loop you can only escape with a full rewrite in phase 3. Better to pay the inception cost once at M1.

5. **Long-term contributor pool.** The Rust ecosystem in privacy/health is growing rapidly through 2025–2026 (Signal, the Bitwarden Rust core, Age, etc.). In 12–18 months the contributor pool in our domain on Rust will match Python's, and may surpass it.

### 8.2. What this decision costs (explicitly)

- **~2–3 additional inception weeks** at M1: Rust scaffolding, `rmcp` ramp-up, `fhirbolt` learning. Included in the M1 buffer budget.
- **~1–2 weeks on FHIR adapters** because of the narrower ecosystem compared to Python. Mitigated by the fact that the FHIR R4 schema is stable — once a parser is written it does not need constant maintenance.
- **A smaller contributor pool in the first year.** Mitigation: clean, well-documented code; explicit "good first issues"; participation in the Rust-health Working Group.
- **Applicant productivity.** The applicant has 11+ years of sysops foundations and 3+ years of MCP development; Rust is a new language, but not a new paradigm. The ramp-up is manageable.

### 8.3. The wins worth paying for

- **Single static binary deployment.** Johann gets `myhealth.exe`/`.dmg`/`.AppImage` and never touches Docker.
- **The strongest security baseline.** Memory safety without a runtime; `cargo audit` for supply chain; `unsafe` blocks are explicit and reviewable.
- **The smallest footprint.** Runs on a Raspberry Pi 4 (2 GB) with headroom.
- **A reasoning-friendly language.** Fewer runtime surprises, valuable for an audit-oriented project.
- **Alignment with the privacy ethos.** Signal, AGE, the Bitwarden core — all Rust. Our project fits in logically.
- **Performance as a side benefit.** p99 latency will never be a blocker.

### 8.4. Why TypeScript and Go are not recommended

- **TypeScript** does not win on any criterion. Loses to Python on FHIR and to Rust on deployment/security.
- **Go** wins on deployment (close to Rust), but the MCP SDK and FHIR ecosystem are weaker, and the security baseline without an explicit `unsafe` boundary makes auditing less crisp.

### 8.5. What would be different if we had chosen Python

- Faster to a working demo (by ~2–3 weeks).
- More potential contributors in phase 1.
- A more complex deployment story → a smaller end-user pool.
- A phase 2 rewrite tax becomes nearly inevitable.
- A larger supply chain attack surface.

This is a trade-off we make consciously: trade ~3 inception weeks for a strategically correct deployment + security baseline.

---

## 9. Concrete tech stack (Rust)

### 9.1. Server-side (Rust)

| Layer | Crate | Version | Purpose |
|-------|-------|---------|---------|
| Toolchain | Rust stable | 1.80+ | Primary |
| Async runtime | `tokio` | latest | Concurrent agents/HTTP |
| MCP server | `rmcp` (Anthropic's official) | latest | MCP protocol implementation |
| FHIR models | `fhirbolt` | latest R4 | Strong-typed FHIR R4 (R5 added in phase 2) |
| FHIR validation | `fhirbolt-shared` + custom validators | latest | Schema + business rule validation |
| Web framework | `axum` + `tower` middleware | latest | UI backend, OAuth endpoints |
| HTTP runtime | `hyper` | latest | Through `axum`/`tokio` |
| Serialization | `serde` + `serde_json` | latest | JSON in/out |
| Storage driver | `rusqlite` (with the `bundled-sqlcipher` feature) | latest | SQLite + encryption-at-rest |
| Encryption | `aes-gcm` + `argon2` + `chacha20poly1305` (optional) | latest crates | AES-256-GCM + Argon2id KDF |
| Key management | `secrecy` + `zeroize` | latest | Zeroing keys in memory, mlock where possible |
| OAuth | `oauth2` + custom JWT signing | latest | Consent gateway |
| JWT | `jsonwebtoken` | latest | Tokens with HMAC-SHA256 |
| Logging | `tracing` + `tracing-subscriber` (JSON output) | latest | Structured JSON logs |
| Testing | `cargo test` + `proptest` + `criterion` | latest | Unit + property-based + benchmarks |
| Lint | `clippy` (deny warnings on main) | latest | Static analysis |
| Format | `rustfmt` | latest | Format |
| Security scan | `cargo-audit` + `cargo-deny` | latest | CVE check + dep policy |
| FFI (optional) | `pyo3` or subprocess | — | If a Python tool integration is needed for testing |
| Cross-compile | `cargo-zigbuild` + `cross` | latest | Linux/macOS/Windows × x86_64/aarch64 |
| Packaging | Native binary + Docker (multi-stage) | — | Distribute |
| Installer (desktop) | `tauri-bundler` for .msi/.dmg/.AppImage/.deb (ADR-008); WiX + cargo-bundle remains as fallback | latest | End-user desktop installers via a Tauri shell over axum |
| Installer (server/headless) | Docker multi-stage image + raw `.deb`/`.rpm` for server scenarios (B, C) | — | Server deployments do not use the Tauri shell — bare Rust binary |
| CI | GitHub Actions with matrix builds | — | Build, test, sign |
| Releases | `cosign` signed | — | Supply chain integrity (SLSA Level 2 target) |
| SBOM | `cargo-cyclonedx` (SBOM in CycloneDX format) | latest | REUSE + SBOM compliance |

### 9.2. Frontend stack (UI client)

The UI client is a web stack — a server-driven MPA via htmx (ADR-007 in `06-architecture.md`). Rust-in-the-browser (via WASM) is overkill for our scope; the browser is the best cross-platform UI runtime for self-hosting.

| Layer | Technology | Purpose |
|-------|-----------|---------|
| Framework | Vanilla JS + htmx (locked in, ADR-007) | Server-driven MPA, minimal build steps, transparent for audit |
| Targeted escape valve | Alpine.js islands | For timeline visualizations of lab values, if richer client state becomes necessary. We do not rewrite the stack |
| Styling | PicoCSS (semantic, classless baseline) + targeted utility classes | Minimalist, no Tailwind build pipeline |
| Bundling | None — htmx via a `<script>` tag from a self-hosted CDN copy; assets are embedded in the Rust binary via `rust-embed` | Zero JS build step as baseline; if an Alpine.js island grows, we add an `esbuild` cmd, not a whole pipeline |
| i18n | Server-side via `axum` + JSON resource bundles (UA, EN, EE, DE, PL) | We render locale-resolved HTML, not client-side i18n |
| Accessibility | `axe-core` in CI on rendered HTML | WCAG 2.1 AA |
| Serving | Through the `axum` static-file handler with embedded assets | Single binary deployment without external file deps |

### 9.3. Native installer wrappers

Desktop scenarios use a Tauri shell over the axum UI backend (ADR-008 in `06-architecture.md`). Server scenarios (Docker, NAS) install the same Rust binary without the Tauri shell — the binary is self-sufficient.

| Platform | Tool | Artifact | Scenario |
|----------|------|----------|----------|
| Windows desktop | `tauri-bundler` (MSI/NSIS) + signed with cert | `MyHealth-Europe-1.0.msi` | A — Johann |
| macOS desktop | `tauri-bundler` (.dmg) + notarization + Apple Developer ID | `MyHealth-Europe-1.0.dmg` | A — Johann |
| Linux desktop | `tauri-bundler` (.AppImage, .deb for the GUI desktop) | `MyHealth-Europe-1.0.AppImage`, `myhealth-europe-desktop-1.0_amd64.deb` | A — Johann on Linux |
| Linux server (headless) | Pure Rust binary without the Tauri shell + Docker image | `myhealth-europe-server-1.0_amd64.deb`, `myhealtheurope/server:1.0` | B, C — Anna, Olha |
| ARM (Raspberry Pi, NAS) | Static binary without Tauri via `cargo-zigbuild --target aarch64-unknown-linux-musl` | `myhealth-europe-1.0-aarch64-linux` | C — community NAS deployments |

Fallback plan (if Tauri starts breaking on some platform): WiX 4 for Windows, `cargo-bundle` for macOS, raw AppImage for Linux. This describes plan B, not the primary path.

---

## 10. Ramp-up and risk management

Because Rust is not the applicant's primary stack, M1 has an explicit ramp-up component with control points.

### 10.1. M1 ramp-up plan (first 4 weeks)

| Week | Activity | Deliverable |
|------|----------|-------------|
| 1 | Rust scaffolding: `cargo new`, CI baseline, `clippy` strict, `tracing` setup | Repo with working CI |
| 1–2 | `rmcp` minimal example — a hello-world MCP server with 1 fictional tool | Echo tool through the MCP Inspector |
| 2 | `fhirbolt` proof — parsing a sample FHIR R4 bundle (e.g., synthetic Synthea) | Demo: bundle.json → typed structs |
| 2–3 | `rusqlite` + encryption proof — encrypted SQLite with AES-GCM resource write | Smoke test write/read of an encrypted record |
| 3 | `axum` UI backend skeleton — static asset serving + REST endpoint | Local UI opens |
| 4 | Integration of all components in a one-binary smoke test | End-to-end: import sample → query → MCP tool returns |

If by the end of week 4 the smoke test passes, we continue per plan. If not — escalation to team review, with possible repositioning of the plan.

### 10.2. Control points

- **End of week 2:** if `rmcp` or `fhirbolt` has a blocker bug — escalation. The fallback plan: switch to Python with a Rust-rewrite plan in phase 2 (the very plan we rejected, but as an emergency exit).
- **End of M1:** working repo with CI, signed releases workflow, baseline smoke test.
- **End of M2:** one FHIR adapter (eHealth UA) fully implemented and tested.

### 10.3. Whether Python is needed for test tools

Yes, but as an external dev dependency, not as a runtime. Specifically:
- **`smart-on-fhir/test-data`** (Python tools) — for generating synthetic FHIR bundles for testing.
- **HL7 Validator (Java) or equivalent** — for cross-validation of our FHIR outputs.

These tools run in CI as subprocesses and are not linked into the production binary.

---


## 11. Open questions for team review

1. ~~**Frontend stack:** vanilla JS + htmx or SvelteKit?~~ **Closed 2026-05-12: htmx (ADR-007).** Server-driven MPA, Alpine.js islands as a targeted escape valve. SvelteKit was rejected because of the Node toolchain and the npm supply chain (the gain in our UI scope does not justify the single-binary thesis).
2. ~~**Installer choice:** Tauri wrapper or simple native installers?~~ **Closed 2026-05-12: Tauri (ADR-008).** Desktop UX for a non-technical patient audience matters more than a few extra MB of binary; Tauri is itself a Rust project, preserving the Rust-first ethos. WiX + cargo-bundle remains as a fallback.
3. ~~**Database choice — SQLCipher vs application-layer AES-GCM:**~~ **Closed 2026-05-12: hybrid (ADR-009).** SQLCipher full-DB encryption as baseline + application-layer AES-GCM for the most sensitive PHI fields (defense-in-depth + per-record key rotation for GDPR erasure). The pure-Rust thesis was overrated (the TLS stack pulls in a C dependency anyway).
4. **Rust async ecosystem stability:** `tokio` as the de-facto standard — OK. Verify that `rmcp` is compatible (yes, it's based on `tokio`).

---

*This decision is tied to the budget (6 PM principal engineer) and team (1 full-time + 1 part-time subcontractor). If the resource envelope changes (e.g., in phase 2 — €100K, 2 full-time engineers), `02-prd.md` and this document are updated accordingly.*

*See: [06-architecture.md](06-architecture.md) for component decomposition; [02-prd.md](02-prd.md) for functional requirements the stack must satisfy.*
