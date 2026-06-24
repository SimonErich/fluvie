#!/usr/bin/env bash
# Build the demo web app, serve it, smoke-test it in headless Chrome, tear down.
# Set SKIP_BUILD=1 to reuse an existing build/web (fast local re-runs).
# CHROME may point at a browser binary (defaults to /usr/bin/google-chrome).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
example="$(cd "$here/../.." && pwd)"
# Ask the OS for a free port unless PORT is pinned, so a busy port never makes
# the smoke test serve (and fail against) the wrong thing.
port="${PORT:-$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')}"
export SHOT="${SHOT:-$here/smoke.png}"

# Resolve a browser from PATH when CHROME is not pinned (CI's setup-chrome adds
# `chrome` to PATH; locally google-chrome is typical).
if [ -z "${CHROME:-}" ]; then
  CHROME="$(command -v google-chrome || command -v google-chrome-stable \
    || command -v chromium || command -v chromium-browser || command -v chrome || true)"
fi
export CHROME
echo "==> chrome: ${CHROME:-<none found>}"

if [ ! -d "$here/node_modules" ]; then
  echo "==> installing harness deps (npm ci)"
  (cd "$here" && npm ci)
fi

if [ "${SKIP_BUILD:-0}" != "1" ]; then
  echo "==> building example web (release)"
  (cd "$example" && flutter build web --release)
fi

echo "==> serving build/web on 127.0.0.1:$port"
python3 -m http.server "$port" --bind 127.0.0.1 --directory "$example/build/web" >/dev/null 2>&1 &
server=$!
trap 'kill "$server" 2>/dev/null || true' EXIT

for _ in $(seq 1 30); do
  curl -sf "http://127.0.0.1:$port/" >/dev/null 2>&1 && break
  sleep 1
done

echo "==> running smoke test"
URL="http://127.0.0.1:$port" node "$here/smoke.mjs"
