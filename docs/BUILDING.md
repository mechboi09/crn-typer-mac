# Build CRN Typer - AUB

Run `bash build-mac.sh` on a Mac with Apple Command Line Tools. This builds arm64 and x86_64 executables, combines them into `CRN Typer - AUB.app`, runs `--self-test`, verifies the local ad-hoc signature, and writes `dist/CRN Typer - AUB.zip` containing only the app. No README is included in the archive. GitHub Actions uses `macos-15-intel` with read-only contents permission. No Apple Developer ID or notarization is configured.
