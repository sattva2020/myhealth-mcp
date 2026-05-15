# syntax=docker/dockerfile:1.7
#
# MyHealth-Europe — Multi-stage Dockerfile
#
# Stages:
#   builder      — Rust toolchain, full cargo build of myhealth-cli
#   development  — Rust toolchain + cargo-watch for hot-reload dev loop
#   production   — Minimal Debian slim + non-root + only the compiled binary
#
# Note: Cargo workspace lives at repo root (`Cargo.toml`), binary crate is
# `myhealth-cli` (planned in M1). Until then this Dockerfile is M1 scaffolding.
#
# SQLCipher: linked via `rusqlite` feature `bundled-sqlcipher`, so no separate
# libsqlcipher install is required in the runtime image.

ARG RUST_VERSION=1.80
ARG DEBIAN_VERSION=bookworm

# ---------------------------------------------------------------------------
# Stage: builder — compile workspace in release mode with BuildKit cache mounts
# ---------------------------------------------------------------------------
FROM rust:${RUST_VERSION}-slim-${DEBIAN_VERSION} AS builder

WORKDIR /usr/src/myhealth

# Native build deps for SQLCipher bundled crypto + TLS roots.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install --no-install-recommends -y \
        pkg-config \
        build-essential \
        ca-certificates \
        libssl-dev \
        clang

# Copy manifests first to leverage layer caching for the dependency build.
COPY Cargo.toml Cargo.lock ./
COPY rust-toolchain.toml ./
COPY crates/ ./crates/

ARG VERSION=dev
ARG COMMIT=unknown
ENV CARGO_TERM_COLOR=always

# Build the binary. `--frozen` enforces Cargo.lock is up to date.
RUN --mount=type=cache,target=/usr/local/cargo/registry,sharing=locked \
    --mount=type=cache,target=/usr/src/myhealth/target,sharing=locked \
    cargo build --release --frozen --workspace --bin myhealth-cli && \
    cp /usr/src/myhealth/target/release/myhealth-cli /usr/local/bin/myhealth-europe && \
    strip /usr/local/bin/myhealth-europe || true

# ---------------------------------------------------------------------------
# Stage: development — full toolchain + cargo-watch for hot reload
# ---------------------------------------------------------------------------
FROM rust:${RUST_VERSION}-slim-${DEBIAN_VERSION} AS development

WORKDIR /app

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install --no-install-recommends -y \
        pkg-config build-essential ca-certificates libssl-dev clang \
        curl tini

RUN --mount=type=cache,target=/usr/local/cargo/registry,sharing=locked \
    cargo install cargo-watch

ENV RUST_LOG=info \
    RUST_BACKTRACE=1 \
    MYHEALTH_BIND=0.0.0.0:7777

EXPOSE 7777

ENTRYPOINT ["tini", "--"]
CMD ["cargo", "watch", "-q", "-c", "-x", "run -p myhealth-cli -- serve"]

# ---------------------------------------------------------------------------
# Stage: production — minimal runtime, non-root user, single binary
# ---------------------------------------------------------------------------
FROM debian:${DEBIAN_VERSION}-slim AS production

ARG VERSION=dev
ARG COMMIT=unknown
LABEL org.opencontainers.image.title="MyHealth-Europe" \
      org.opencontainers.image.description="Open-source MCP server for citizen-controlled EU health data" \
      org.opencontainers.image.source="https://github.com/sattva2020/myhealth-mcp" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${COMMIT}"

# Runtime deps:
#   - ca-certificates: HTTPS to MCP clients / OAuth flows
#   - tini: PID-1 + proper SIGTERM forwarding (NFR-O5 graceful shutdown)
#   - curl: liveness probe target for /healthz (NFR-O4)
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install --no-install-recommends -y \
        ca-certificates tini curl && \
    rm -rf /var/lib/apt/lists/*

# Non-root user (matches compose.production.yml `user: 1001:1001`).
RUN groupadd --system --gid 1001 myhealth && \
    useradd  --system --uid 1001 --gid myhealth --home /var/lib/myhealth \
             --shell /usr/sbin/nologin myhealth && \
    mkdir -p /var/lib/myhealth /var/log/myhealth && \
    chown -R 1001:1001 /var/lib/myhealth /var/log/myhealth

COPY --from=builder /usr/local/bin/myhealth-europe /usr/local/bin/myhealth-europe

USER 1001:1001
WORKDIR /var/lib/myhealth

ENV MYHEALTH_BIND=0.0.0.0:7777 \
    MYHEALTH_DATA_DIR=/var/lib/myhealth \
    MYHEALTH_LOG_DIR=/var/log/myhealth \
    RUST_LOG=info

EXPOSE 7777

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl --fail --silent --show-error http://127.0.0.1:7777/healthz || exit 1

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/myhealth-europe"]
CMD ["serve"]
