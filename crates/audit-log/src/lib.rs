//! Append-only audit log with HMAC-chain tamper evidence.
//!
//! See docs/06-architecture.md §2.5 and ADR-005. Each event includes a HMAC
//! that incorporates the previous event's hash, so any historical edit breaks
//! the chain and is detectable on read.
//!
//! Records NO PHI — only event metadata (counts, types, dates, agent IDs).
