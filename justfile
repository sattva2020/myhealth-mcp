# MyHealth-Europe — local development commands.
# Install just: https://github.com/casey/just
# Usage: `just <recipe>` or `just` for the default check, `just help` for the recipe list.

# Auto-load .env (DATABASE_URL, GITHUB_TOKEN, etc.) when present.
set dotenv-load := true

default: check

# Self-documenting recipe list with one-line descriptions.
help:
    @just --list --unsorted

# All-green gate before any commit or release.
check: fmt-check lint test

# Lighter aggregate target for CI matrix jobs (no audit/deny/sbom).
ci: fmt-check lint test build

# Format the entire workspace (write changes).
fmt:
    cargo fmt --all

# Check formatting without writing (for pre-commit / pre-release).
fmt-check:
    cargo fmt --all --check

# Strict clippy — same lint level we'd enforce at release time.
lint:
    cargo clippy --workspace --all-targets --all-features -- -D warnings

# Apply clippy auto-fixes (review the diff before committing).
lint-fix:
    cargo clippy --workspace --all-targets --all-features --fix --allow-dirty --allow-staged

# Run all tests across the workspace.
test:
    cargo test --workspace --all-features

# Run only doc-tests across the workspace.
test-doc:
    cargo test --workspace --all-features --doc

# Run code coverage (lines + branches). Install: cargo install cargo-llvm-cov
coverage:
    cargo llvm-cov --workspace --all-features --html
    @echo "Coverage report: target/llvm-cov/html/index.html"

# CI-friendly coverage with lcov output for codecov/coveralls upload.
coverage-ci:
    cargo llvm-cov --workspace --all-features --lcov --output-path lcov.info

# Run criterion benchmarks (NFR-P1: p99 <200ms on 10K records).
bench:
    cargo bench --workspace

# Debug build (fast iteration).
build:
    cargo build --workspace --all-features

# Build a release binary (debug-stripped, LTO, single-codegen).
build-release:
    cargo build --workspace --release

# Cross-compile for Linux ARM64 (Raspberry Pi 4 target — NFR-P6).
# Install: cargo install cross
cross-linux-arm64:
    cross build --workspace --release --target aarch64-unknown-linux-gnu

# Cross-compile for Linux x86_64.
cross-linux-x64:
    cross build --workspace --release --target x86_64-unknown-linux-gnu

# Cross-compile for Windows x86_64 (uses zig as linker for portability).
# Install: cargo install cargo-zigbuild
cross-windows:
    cargo zigbuild --workspace --release --target x86_64-pc-windows-gnu

# Cross-compile for macOS Apple Silicon.
cross-macos-arm64:
    cargo zigbuild --workspace --release --target aarch64-apple-darwin

# Cross-compile for macOS Intel.
cross-macos-x64:
    cargo zigbuild --workspace --release --target x86_64-apple-darwin

# Run the CLI binary in debug mode (placeholder until myhealth-cli crate exists).
run *ARGS:
    cargo run -p myhealth-cli -- {{ARGS}}

# Hot-reload dev loop for the UI/MCP server.
# Install: cargo install cargo-watch
dev:
    cargo watch -q -c -x "run -p myhealth-cli -- serve"

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

# Update the dependency graph and regenerate Cargo.lock.
update:
    cargo update

# Show outdated dependencies (install: cargo install cargo-outdated).
outdated:
    cargo outdated --workspace --root-deps-only

# Open the workspace docs in your default browser.
docs:
    cargo doc --workspace --no-deps --open

# Clean all build outputs.
clean:
    cargo clean

# --- Docker -----------------------------------------------------------------

# Start dev environment (cargo-watch hot reload on bind-mounted source).
docker-dev:
    docker compose up

# Stop dev environment and remove named volumes (DATA LOSS!).
docker-dev-down:
    docker compose down -v

# Build the production image locally (target=production, multi-stage).
docker-build:
    docker compose build --build-arg VERSION="$(git describe --tags --always --dirty)" --build-arg COMMIT="$(git rev-parse --short HEAD)"

# Run hardened production overlay (127.0.0.1 bind, read_only, cap_drop ALL).
docker-prod-up:
    docker compose -f compose.yml -f compose.production.yml up -d

# Tail logs from the production overlay.
docker-prod-logs:
    docker compose -f compose.yml -f compose.production.yml logs -f app

# Stop production overlay (keeps volumes).
docker-prod-down:
    docker compose -f compose.yml -f compose.production.yml down
