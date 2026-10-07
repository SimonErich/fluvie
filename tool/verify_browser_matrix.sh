#!/usr/bin/env bash
# Requires a release web build and vendored FFmpeg assets. Installs test-only
# tooling under ignored build/, leaving production dependencies unchanged.
set -euo pipefail
BROWSER_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BROWSER_TOOLS="$BROWSER_REPO/build/release-hardening/browser-tools"
BROWSER_INSTALL_ARGS=()
case "${1:-}" in
  '') ;;
  --with-deps) BROWSER_INSTALL_ARGS+=(--with-deps) ;;
  *) echo 'Usage: verify_browser_matrix.sh [--with-deps]' >&2; exit 2 ;;
esac
if [ ! -f "$BROWSER_TOOLS/node_modules/playwright-core/package.json" ] || \
   [ "$(node -p "require(process.argv[1]).version" "$BROWSER_TOOLS/node_modules/playwright-core/package.json")" != '1.62.1' ]; then
  npm install --prefix "$BROWSER_TOOLS" --package-lock=false --no-audit --no-fund playwright-core@1.62.1
fi
node "$BROWSER_TOOLS/node_modules/playwright-core/cli.js" install "${BROWSER_INSTALL_ARGS[@]}" firefox webkit
node "$BROWSER_REPO/tool/verify_browser_matrix.mjs"
