#!/usr/bin/env bash
# Install the Fluvie git hooks by pointing git at the committed hooks dir.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
git -C "$ROOT" config core.hooksPath .githooks
chmod +x "$ROOT/.githooks/pre-commit" "$ROOT/.githooks/commit-msg"
echo "✓ Fluvie git hooks installed (core.hooksPath = .githooks)."
