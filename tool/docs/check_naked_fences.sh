#!/usr/bin/env bash
# CI/whole-tree naked-fence gate: fail if any ```dart fence under the given
# directory (default: documentation) lacks a preceding code-excerpt directive.
# Mirrors the pre-commit hook's per-file check (see .githooks/_lib.sh).
set -euo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.githooks" && pwd)"
# shellcheck source=../../.githooks/_lib.sh
source "$HOOK_DIR/_lib.sh"

root="${1:-documentation}"
fail=0

while IFS= read -r -d '' f; do
  content="$(cat "$f")"
  naked="$(printf '%s\n' "$content" | naked_dart_fences)"
  if [ -n "$naked" ]; then
    for ln in $naked; do
      echo "✗ $f:$ln: naked \`\`\`dart fence — add a <!-- code-excerpt \"<file> (<region>)\" --> directive (or code-excerpt-ignore)."
    done
    fail=1
  fi
done < <(find "$root" -name '*.md' -type f -print0)

if [ "$fail" -ne 0 ]; then
  echo ""
  echo "Naked dart fences found. Compile the snippet and reference it with a code-excerpt directive."
  exit 1
fi

echo "✓ docs:lint passed (every dart fence has a code-excerpt directive)."
