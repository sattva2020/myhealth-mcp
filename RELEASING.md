# Releasing MyHealth-Europe

This project ships releases **manually**, from a developer workstation.
No GitHub Actions, no automated CI — see `docs/05-tech-stack.md` and
the project's solo-dev workflow.

Each release is signed and accompanied by a CycloneDX SBOM, satisfying the
supply-chain claims in `docs/02-prd.md` NFR-S4 without requiring CI infra.

## Pre-release checklist

Run these from a clean checkout of `main`:

```powershell
# 1. Sync
git fetch origin
git checkout main
git pull --ff-only

# 2. Make sure the working tree is clean
git status   # must be empty

# 3. All-green local gate
just pre-release
```

`just pre-release` covers:

- `cargo fmt --check`
- `cargo clippy --deny warnings`
- `cargo test --workspace`
- `cargo audit`            (CVE scan)
- `cargo deny check`       (license + bans + advisories)
- `cargo build --release`
- `cargo cyclonedx`        (SBOM in CycloneDX JSON)

If any step fails — fix and re-run. Do not tag a release with a yellow gate.

## Versioning

Semantic Versioning 2.0. Bump the `version` field in the workspace root
`Cargo.toml` only — sub-crates inherit via `version.workspace = true`.

- `0.x.y` while in pre-release. M9 cuts the first `1.0.0`.

## Tag and release

```powershell
# Tag the release commit
git tag -s v0.1.0 -m "v0.1.0 — initial scaffolding"

# Push the tag
git push origin v0.1.0
```

`-s` produces a GPG-signed tag if you have a key configured. If not,
use `git tag -a v0.1.0 -m "..."` and add cosign signing on the binary instead.

## Sign the binary

```powershell
# Per platform, after release build
cosign sign-blob `
    --bundle target/release/myhealth-v0.1.0-x86_64-pc-windows-msvc.bundle `
    target/release/myhealth.exe

# Verify (the next person can also do this)
cosign verify-blob `
    --bundle target/release/myhealth-v0.1.0-x86_64-pc-windows-msvc.bundle `
    --certificate-identity ruslan@griban.dev `
    --certificate-oidc-issuer https://github.com/login/oauth `
    target/release/myhealth.exe
```

## Attach artifacts to GitHub Release

Create a Release on GitHub against the tag, attach:

- `myhealth-<version>-<target>.exe` (or `.dmg` / `.AppImage`)
- `myhealth-<version>-<target>.bundle` (cosign signature)
- `sbom.cdx.json` (CycloneDX SBOM)
- `CHANGELOG.md` excerpt for this version

## Rollback

If a release turns out broken:

1. **Yank** the GitHub Release (mark as pre-release, add a warning in the description).
2. **Do not delete the tag** — that breaks reproducibility for anyone who pulled.
3. Issue a patch release (`v0.1.1`) with the fix and a `superseded-by` note in the CHANGELOG entry of the broken one.
