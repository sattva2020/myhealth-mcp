# MyHealth-Europe — local development commands.
# Install just: https://github.com/casey/just
# Usage: `just <recipe>` or `just` for the default check.

default: check

# All-green gate before any commit or release.
check: fmt-check lint test

# Format the entire workspace (write changes).
fmt:
    cargo fmt --all

# Check formatting without writing (for pre-commit / pre-release).
fmt-check:
    cargo fmt --all --check

# Strict clippy — same lint level we'd enforce at release time.
lint:
    cargo clippy --workspace --all-targets --all-features -- -D warnings

# Run all tests across the workspace.
test:
    cargo test --workspace --all-features

# Build a release binary (debug-stripped, LTO, single-codegen).
build-release:
    cargo build --workspace --release

# Run cargo-audit for known CVEs in the dependency graph.
# Install: cargo install cargo-audit
audit:
    cargo audit

# Run cargo-deny policy check (licenses, banned crates, advisories).
# Install: cargo install cargo-deny
deny:
    cargo deny check

# Generate CycloneDX SBOM for the release artifact.
# Install: cargo install cargo-cyclonedx
sbom:
    cargo cyclonedx --format json --output-pattern bundled

# Pre-release gate — everything that must pass before tagging.
pre-release: check audit deny build-release sbom

# Open the docs in your default browser (Windows / macOS / Linux).
docs:
    cargo doc --workspace --no-deps --open

# Clean all build outputs.
clean:
    cargo clean
