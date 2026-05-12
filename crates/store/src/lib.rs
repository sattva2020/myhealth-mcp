//! Local store for encrypted FHIR records.
//!
//! See docs/06-architecture.md §2.2 and ADR-009.
//!
//! Encryption layers:
//! 1. **SQLCipher** — full-DB encryption (AES-256 page level). Baseline.
//! 2. **AES-GCM column-level** — for highest-sensitivity PHI (free-text notes,
//!    mental health observations, diagnostic narratives). Defense-in-depth +
//!    per-record key rotation for GDPR right-to-erasure.
//!
//! Key derivation: Argon2id (≥64MB memory, ≥3 iter) from user passphrase.
//! Keys live only in RAM via `secrecy::Secret<[u8; 32]>` + zeroize on drop.
