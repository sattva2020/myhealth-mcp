# Security Rules

> Area-specific security conventions, derived from `docs/08-threat-model.md` (STRIDE analysis of 22 threats).
> Loaded after `rules/base.md` for security-related code.

## Rules

- No `.unwrap()` / `.expect()` on security-critical paths (consent gateway, encryption, audit) — even in dev builds.
- PHI is **never** emitted into `Display`/`Debug`, error messages, logs, or panic outputs. Reveal only identifiers (record id, resource type, source).
- All keys are `secrecy::SecretString`/`SecretVec` with `#[derive(ZeroizeOnDrop)]`; `String`/`Vec<u8>` for secrets is forbidden.
- Argon2id KDF: memory ≥64 MB, iterations ≥3, parallelism 1, salt 16 bytes. Separate derived keys for SQLCipher full-DB and the application-layer column-level master (ADR-009).
- Column-level AES-256-GCM on the most sensitive PHI fields (free-text notes, mental health observations, diagnostic narratives) — per-record key wrapped under master, 96-bit nonce, 128-bit tag.
- Token signing — HMAC-SHA256 with a 256-bit per-instance secret. JWT validation — constant-time comparison (T-C6).
- OAuth 2.1 + PKCE are mandatory. No implicit flow, no static client secrets.
- Default deny on broad scopes (`read:all:*`); the UI prompt requires an explicit user-action timestamp + typing confirmation for broad/sensitive scopes (T-M2).
- Per-resource-type confirmation for sensitive categories: psych, sexual, genetic (FR-4.5).
- Time-bound tokens with max TTL 30 days. Presets: 5 min / 1 h / 24 h / 7 d / 30 d. No persistent tokens without an explicit warning (FR-4.3).
- Token revocation — in-memory + persisted revocation list with jti tracking; a revoked token must fail in constant time (T-C2).
- Defense-in-depth: scope check in the Consent Gateway **AND** in the MCP tool handler. Unit tests for scope leakage are mandatory (T-M3).
- MCP tool error responses are sanitized; no PHI in any error message even on internal errors (T-M4).
- MCP data for the agent is marked as a `<data>` block, not as instructions — protection against prompt injection via `Observation.note` (T-M5).
- The SSE/HTTP MCP transport is **off by default**. When opted in, TLS 1.3 + OAuth + bind to 127.0.0.1 are mandatory (T-M7).
- The UI's default bind is 127.0.0.1, not 0.0.0.0. LAN/remote access requires an explicit user opt-in with TLS (T-U5).
- HTTP cookies: `HttpOnly`, `Secure` (when TLS), `SameSite=Strict`. CSRF tokens on all consent endpoints (T-C3, T-U3).
- CSP `default-src 'self'`; `X-Frame-Options: DENY` + `frame-ancestors 'none'` for anti-clickjacking (T-U2, T-U4).
- HTML output — strict escaping; FHIR records render as text, not via innerHTML (T-U2).
- Audit log — append-only constraint (no `UPDATE`/`DELETE`); HMAC chain with the hash of the previous event for tamper-evidence (T-S4, T-L1).
- Every grant/deny/revoke/read is a separate audit event with metadata (no PHI in the event payload — only counts, types, dates) (T-L2).
- Per-record HMAC-MAC for every PHI record; integrity check on read (T-S3).
- Streaming FHIR parser with a max file size of 250 MB by default; a safe XML parser (defused-style); JSON depth/size limits (T-A1, T-A3).
- Property-based + fuzz testing for the CDA→FHIR converter and the scope checker (T-A4, T-M3).
- No outbound network from the server process by default; CI has network egress monitoring in tests.
- `unsafe` blocks are forbidden without an explicit ADR in `docs/adr/` plus a security review.
- Supply chain: `Cargo.lock` checked into the repo; `cargo audit` + `cargo deny` in CI fail-on-finding; SBOM (CycloneDX) with every release; cosign-signed releases (T-B1, T-B2).
- Release artifacts — SLSA Level 2 target; OIDC in CI instead of static tokens (T-B3).
- The setup wizard requires a passphrase ≥12 chars + zxcvbn strength score ≥3 before creating the store.
- Secret scanning in CI: Trufflehog/Gitleaks on pre-commit and in GitHub Actions; no hardcoded keys in code/tests/fixtures (test keys are generated per test).
- Memory hygiene: mlock on keys where possible; zeroising via `zeroize` after use; recommend encrypted swap in the docs (T-S2).
