//! MCP server surface for AI agents.
//!
//! Tools (read-only in phase 1): `get_observations`, `get_medications`,
//! `get_conditions`, `get_allergies`, `get_immunizations`, `get_encounters`,
//! `get_diagnostic_reports`, `get_health_summary`, `search_records`.
//! Each tool checks `consent-gateway` scope BEFORE calling `store`.
//!
//! Transports: stdio (default, ADR-003) + opt-in SSE/HTTPS via axum.
