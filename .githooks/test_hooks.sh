#!/usr/bin/env bash
# Self-test for the pre-commit gate helpers. Run directly (`bash
# .githooks/test_hooks.sh`) or from CI. Guards against the gate silently
# rotting into a no-op: it proves the code-construct stripper still strips
# comments/strings AND that a real violation in live code is still caught.
set -euo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "$HOOK_DIR/_lib.sh"

fail=0
note() { echo "  $1"; }

# A code-construct violation in LIVE code must survive stripping and match.
bad=$'void main() {\n  print("x");\n  final r = 1;\n  final x = r as dynamic;\n}'
stripped="$(printf '%s' "$bad" | strip_dart_comments_and_strings)"
for entry in "${FORBIDDEN_CODE_PATTERNS[@]}"; do
  pat="${entry%%|*}"
  if ! printf '%s\n' "$stripped" | grep -qE "$pat"; then
    note "FAIL: live-code pattern not caught: ${entry%%|*}"
    fail=1
  fi
done

# The same constructs inside comments / strings / dartdoc must NOT match.
ok=$'/// Example: print("hi") and DateTime.now()\nconst s = '\'\'\''void main() => print("x");'\'\'\'';\nfinal y = "Random() text";'
strippedok="$(printf '%s' "$ok" | strip_dart_comments_and_strings)"
for entry in "${FORBIDDEN_CODE_PATTERNS[@]}"; do
  pat="${entry%%|*}"
  if printf '%s\n' "$strippedok" | grep -qE "$pat"; then
    note "FAIL: false positive in comment/string: ${entry%%|*}"
    fail=1
  fi
done

# A stripper that returns empty for non-empty input is the regression we hit.
if [ -z "$stripped" ]; then
  note "FAIL: stripper returned empty for live code (it is a no-op)."
  fail=1
fi

# --- Docs-lint (naked-fence gate) ---

# A bare ```dart fence with no preceding code-excerpt directive is rejected.
naked_md=$'# Page\n\n```dart\nfinal x = 1;\n```\n'
if [ -z "$(printf '%s' "$naked_md" | naked_dart_fences)" ]; then
  note "FAIL: a naked dart fence was not flagged."
  fail=1
fi

# A fence preceded by a code-excerpt directive passes.
ok_md=$'# Page\n\n<!-- code-excerpt "example/lib/x.dart (region)" -->\n```dart\nfinal x = 1;\n```\n'
if [ -n "$(printf '%s' "$ok_md" | naked_dart_fences)" ]; then
  note "FAIL: a code-excerpt-preceded fence was wrongly flagged."
  fail=1
fi

# The narrow code-excerpt-ignore opt-out passes too.
ignore_md=$'<!-- code-excerpt-ignore: meta-example -->\n```dart\n// coverage:ignore-line: x\n```\n'
if [ -n "$(printf '%s' "$ignore_md" | naked_dart_fences)" ]; then
  note "FAIL: a code-excerpt-ignore fence was wrongly flagged."
  fail=1
fi

# A four-backtick fence (a Markdown block, not a snippet) is not flagged.
quad_md=$'# Page\n\n````dart\n```dart\nvoid main() {}\n```\n````\n'
if [ -n "$(printf '%s' "$quad_md" | naked_dart_fences)" ]; then
  note "FAIL: a four-backtick dart fence was wrongly flagged."
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  echo "✗ hook self-test failed."
  exit 1
fi
echo "✓ hook self-test passed (stripper strips comments/strings, catches live violations, naked-fence gate works)."
