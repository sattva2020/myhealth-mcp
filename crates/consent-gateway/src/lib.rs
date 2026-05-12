//! OAuth 2.1 + PKCE consent gateway.
//!
//! Issues JWT tokens with HMAC-SHA256 (local-only secret), scoped to
//! `operation:resource_type:category[:filter]` strings (e.g.
//! `read:observations:lab:date>=2025-01`). TTL presets: 5min/1h/24h/7d.
//!
//! Every issuance, denial, and revocation lands in `audit-log` (ADR-005).
