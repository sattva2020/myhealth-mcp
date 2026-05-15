# OAuth 2.1 + PKCE Reference

> Source: https://datatracker.ietf.org/doc/draft-ietf-oauth-v2-1/ (Internet-Draft, draft-13 current as of 2026-05), https://www.rfc-editor.org/rfc/rfc7636 (PKCE, normative RFC)
> Created: 2026-05-12
> Updated: 2026-05-12
> Note: the full draft-ietf-oauth-v2-1 and RFC 7636 could not be fetched inline (one is 66 KB, the other is behind a Cloudflare challenge). This reference is synthesized from the established content of draft-13 and RFC 7636 (2015). To verify exact wording — `/aif-reference --update` once datatracker becomes accessible without a challenge or after draft-14+ is released.

## Overview

**OAuth 2.1** is the consolidation of OAuth 2.0 + WG best current practices (BCP). It removes unsafe grant types (implicit, resource-owner password credentials), makes **PKCE mandatory** for all authorization-code flows (previously — only for public clients), forbids bearer tokens in the query string, and normalizes redirect URI matching to exact-match.

**PKCE** (Proof Key for Code Exchange, RFC 7636) protects the authorization-code flow from interception attacks: the client generates a cryptographically random `code_verifier`, sends its SHA-256 hash as `code_challenge` during auth, and then reveals the `verifier` when exchanging the code for a token. An attacker who intercepts the auth code cannot use it without the verifier.

For MyHealth-Europe — OAuth 2.1 + PKCE is the foundation of the Consent Gateway (M5).

## Core Concepts

### Roles

- **Resource owner** — the user who owns the health data.
- **Client** — the AI agent (Claude Desktop, Ollama, etc.) that wants access.
- **Authorization server (AS)** — the Consent Gateway inside MyHealth-Europe. Issues tokens.
- **Resource server (RS)** — the MCP-server portion of MyHealth-Europe. Validates tokens before serving data.

In a single-binary deployment, AS + RS share one process space, but they are logically separate trust boundaries.

### Grant types (OAuth 2.1)

| Grant                                | Allowed in OAuth 2.1  | Purpose                                |
| ------------------------------------ | --------------------- | -------------------------------------- |
| Authorization Code + PKCE            | yes (mandatory PKCE)   | Browser-based flow, primary            |
| Refresh Token                        | yes (sender-constrained) | Renewal of access tokens             |
| Client Credentials                   | yes                    | Machine-to-machine (no user)           |
| Device Authorization                 | yes                    | Devices without a browser              |
| Implicit                             | no (deprecated)        | —                                      |
| Resource Owner Password Credentials  | no (deprecated)        | —                                      |

For MyHealth-Europe the relevant ones are: **Authorization Code + PKCE** (Claude Desktop flow) and potentially **Device Authorization** (for headless RPi deployments with the UI on another device).

### PKCE flow

```
+--------+                                          +---------------+
|        |--(A)- Authorization Request --->        |   Resource    |
|        |       + code_challenge                  |     Owner     |
|        |       + code_challenge_method=S256      |               |
|        |                                          +-------+-------+
|        |                                                  |
|        |                                                  v (user approves)
|        |                                          +-------+-------+
|        |<-(B)- Authorization Code ---           | Authorization |
| Client |                                          |     Server    |
|        |                                          +-------+-------+
|        |                                                  ^
|        |--(C)- Token Request ---------->                  |
|        |       + authorization_code                       |
|        |       + code_verifier                            |
|        |                                                  |
|        |<-(D)- Access Token ---                           |
|        |       (+ refresh_token)                          |
+--------+
```

### PKCE parameters (RFC 7636)

**`code_verifier`** — high-entropy cryptographic random string:

- Symbol set: `[A-Z] [a-z] [0-9] - . _ ~` (unreserved characters per RFC 3986)
- Length: 43-128 characters
- Generated client-side, never sent in step (A)

**`code_challenge`** — derived from the verifier:

- Method `plain` — `code_challenge == code_verifier`. NOT RECOMMENDED.
- Method `S256` — `code_challenge = BASE64URL-ENCODE(SHA256(ASCII(code_verifier)))`. **Mandatory for OAuth 2.1.**

**`code_challenge_method`** — `S256` (mandatory for OAuth 2.1; `plain` deprecated).

## API / Interface

### Endpoint: Authorization (step A)

`GET /authorize?response_type=code&client_id=...&redirect_uri=...&scope=...&state=...&code_challenge=...&code_challenge_method=S256`

Parameters:

| Param                   | Required | Description                                                                           |
| ----------------------- | -------- | ------------------------------------------------------------------------------------- |
| `response_type`         | required | Always `code` (the implicit grant is forbidden in OAuth 2.1)                         |
| `client_id`             | required | Client ID                                                                             |
| `redirect_uri`          | required | EXACT match with the registered one (OAuth 2.1 forbade substring matching)            |
| `scope`                 | optional | Space-separated scope tokens                                                          |
| `state`                 | recommended | Opaque value for CSRF protection                                                  |
| `code_challenge`        | required | PKCE challenge (43-128 chars, base64url(sha256(verifier)))                            |
| `code_challenge_method` | required | `S256` (mandatory in OAuth 2.1)                                                       |

### Endpoint: Token (step C)

`POST /token` with `Content-Type: application/x-www-form-urlencoded`:

```
grant_type=authorization_code
&code=<authorization_code>
&redirect_uri=<same as in step A>
&client_id=<client_id>
&code_verifier=<original_verifier>
```

**Response (success):**

```json
{
  "access_token": "...",
  "token_type": "Bearer",
  "expires_in": 3600,
  "refresh_token": "...",
  "scope": "..."
}
```

**Response (error):** `{"error": "invalid_grant", "error_description": "..."}`. Common codes: `invalid_request`, `invalid_client`, `invalid_grant`, `unauthorized_client`, `unsupported_grant_type`, `invalid_scope`.

### Refresh Token (sender-constrained)

`POST /token`:

```
grant_type=refresh_token
&refresh_token=<token>
&client_id=<client_id>
```

OAuth 2.1 requires sender-constrained refresh tokens. Options: rotation (new refresh token on each use) or DPoP (proof-of-possession).

### Token usage

Bearer token in the HTTP `Authorization` header:

```
GET /api/...
Authorization: Bearer <access_token>
```

**OAuth 2.1 FORBIDS tokens in query strings** (previously possible via `?access_token=...`). Header only.

## Configuration

### Token lifetimes (for MyHealth-Europe)

| Token type     | TTL (recommendation) | MyHealth-Europe target               |
| -------------- | -------------------- | ------------------------------------ |
| Access token   | 1h                   | 5 min / 1 h / 24 h / 7d / 30d max (per-session user choice) |
| Refresh token  | days–weeks           | Rotated on each use; max lifetime per session |
| Auth code      | <= 10 min            | 5 min (single-use)                   |

### Scope encoding (proposed for MyHealth-Europe)

```
read:observations         # all Observations
read:observations:lab     # only the lab subset
read:medications:active   # only active medications
read:conditions
read:allergies
read:immunizations
read:encounters
read:diagnostic-reports
read:summary              # health summary (aggregate)
```

Multiple scopes — space-separated in the `scope` param.

## Best Practices

1. **PKCE — for all authorization-code flows.** OAuth 2.1 makes this mandatory; do not treat it as "only for public clients".
2. **Only `S256`.** `plain` — to be forbidden in the Consent Gateway even if RFC 7636 technically allows it.
3. **Exact-match redirect URI.** No wildcards, no substring matching, no path-prefix matching.
4. **One-time auth codes.** Single-use, max 10 min TTL. Track used codes in a store for idempotency.
5. **Sender-constrained refresh tokens.** Rotate on each use; the old refresh token is invalidated. Detect replay (an old token used after rotation) — signal of attack, revoke the ENTIRE family of tokens.
6. **Bearer tokens — only in the `Authorization` header.** Not in the query string, not in cookies (XSS risk).
7. **HTTPS is mandatory** for all endpoints, except localhost (development).
8. **Token introspection or self-contained JWT.** MyHealth-Europe uses HMAC-SHA256 JWT with a secret key in the Consent Gateway — fast, with no round trip to the AS.
9. **Audit-log every grant/deny/revoke/refresh.** Append-only, with `client_id`, `scope`, `timestamp`, `decision`, and no PHI.
10. **State param + CSRF protection.** Always send `state` in /authorize, validate it at the callback.

## Common Pitfalls

- **PKCE `plain` method.** Technically allowed by RFC 7636, but OAuth 2.1 deprecates it. Forbid it explicitly in the Consent Gateway.
- **Code verifier shorter than 43 characters.** Specifically chosen for cryptographic strength (minimum 256 bits of entropy under S256). Less — security regression.
- **Reuse of access tokens in the redirect URL.** Auto-fail from a security standpoint.
- **Tokens in logs.** The `tracing` filter MUST redact `access_token`, `refresh_token`, `code`, `code_verifier`, the `Authorization` header.
- **Allowing wildcards in redirect URI matching.** A general CSRF vector + token-leak vector. OAuth 2.1 explicitly forbids this.
- **HTTP instead of HTTPS** on non-localhost. Catastrophic — any middleware intercepts the tokens.
- **Failing to validate `iss` in the JWT.** If the Consent Gateway issues a token for one instance and another instance accepts it — leak. Always validate the issuer claim.
- **Allowing the implicit grant.** OAuth 2.1 removed it, even for browser-only clients. Use authorization-code + PKCE.
- **Using bearer in the query for SSR.** SSE/Streamable-HTTP transports have specific patterns; force the header via an `EventSource` polyfill or a custom transport.

## Security Considerations (from RFC 7636 Section 4)

1. **Code verifier MUST be cryptographically random** — from a CSPRNG, not from `Math.random()` equivalents.
2. **Use S256 in production.** `plain` only when `S256` is technically not possible (legacy systems).
3. **Never log the verifier.** Same as tokens.
4. **TLS is mandatory** on the token endpoint.
5. **The authorization code is single-use.** The server tracks consumed codes; a repeat `/token` with the same code → error.

## Integration with MyHealth-Europe

- **Crate:** `myhealth-consent` — implements the Consent Gateway.
- **Library `oauth2`** — Rust crate for server-side OAuth 2.0/2.1. Sane defaults, but the PKCE flow sometimes needs to be configured by hand.
- **JWT:** the `jsonwebtoken` crate, HMAC-SHA256. The secret is derived from a passphrase via Argon2id and is never written to disk.
- **Token store:** `myhealth-store` via the `ConsentStore` port. Append-only for audit.
- **OAuth endpoints (axum routes):**
  - `GET /oauth/authorize` — render the consent UI, fetch client_id, scopes, validate the PKCE challenge format
  - `POST /oauth/token` — exchange code for tokens (validate the verifier)
  - `POST /oauth/revoke` — revoke a token (audit-log)
  - `POST /oauth/introspect` — internal endpoint (for the MCP-server portion)
- **Per-resource-type confirmation for sensitive scopes** — `read:observations:psych`, `read:observations:sexual`, `read:observations:genetic` — additional prompt steps, separate audit tag.
- **Trust boundary:** any MCP tool that reads data MUST go through `consent.validate(token, scope, resource_type)` before the actual store request.

## Open Questions / TODO

- **DPoP vs. refresh-token rotation.** OAuth 2.1 allows both sender-constraint approaches. In phase 1 — rotation is simpler; DPoP — for the future.
- **`mcp-security.md` reference** separately describes how the MCP spec integrates with OAuth 2.1 — fetch when it appears on the horizon.
- **Token revocation propagation.** If an access token is revoked, the MCP server must drop in-flight requests. The pattern is not fixed — an ADR is needed.
