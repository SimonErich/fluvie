#!/usr/bin/env bash
# Serve a built Fluvie web example and run the render e2e against it.
#   BUILD_DIR=<path to build/web> bash tool/web/e2e/run.sh
# CHROME may point at a browser binary (CI's setup-chrome adds one to PATH).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
build_dir="${BUILD_DIR:?set BUILD_DIR to the app's build/web directory}"
port="${PORT:-$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')}"

if [ -z "${CHROME:-}" ]; then
  CHROME="$(command -v google-chrome || command -v google-chrome-stable \
    || command -v chromium || command -v chromium-browser || command -v chrome || true)"
fi
export CHROME
echo "==> chrome: ${CHROME:-<none found>}"

[ -d "$here/node_modules" ] || (cd "$here" && npm ci)

python3 -m http.server "$port" --bind 127.0.0.1 --directory "$build_dir" >/dev/null 2>&1 &
server=$!
trap 'kill "$server" 2>/dev/null || true' EXIT

for _ in $(seq 1 30); do
  curl -sf "http://127.0.0.1:$port/" >/dev/null 2>&1 && break
  sleep 1
done

echo "==> running render e2e against http://127.0.0.1:$port"
URL="http://127.0.0.1:$port" node "$here/e2e_render.mjs"
