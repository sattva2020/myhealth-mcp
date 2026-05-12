//! MyHealth-Europe — main binary entrypoint.
//!
//! For now this is a placeholder. Real wiring happens during M1+:
//! - parse config and CLI args
//! - initialize tracing
//! - boot `audit-log`, then `store`, then `consent-gateway`, then `mcp-server`,
//!   then `axum` UI backend on 127.0.0.1:7777
//! - install Ctrl-C handler for graceful shutdown

fn main() {
    println!("MyHealth-Europe v{} — scaffold", env!("CARGO_PKG_VERSION"));
    println!("See docs/ for architecture, PRD, and threat model.");
}
