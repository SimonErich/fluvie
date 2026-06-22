#!/usr/bin/env bash
# Shared helpers for Fluvie git hooks. Sourced by pre-commit.
set -euo pipefail

# Forbidden substrings in staged Dart files (quality gate). These live in
# comments by nature (a leftover TODO is a comment), so they match the raw
# file content. Format per entry: "<extended-regex>|<human message>".
FORBIDDEN_PATTERNS=(
  'TODO|leftover TODO comment'
  'FIXME|leftover FIXME comment'
)

# Forbidden CODE constructs (determinism + quality). These are matched against
# the file with comments and string literals stripped, so a `print(` inside a
# dartdoc example or a highlighted-code test fixture is not a false positive;
# only a real statement-level occurrence trips the gate.
FORBIDDEN_CODE_PATTERNS=(
  'print\(|use of print() — use stderr/logging'
  ' as dynamic|cast to dynamic'
)

# Strip comments (`//`, `/* */`) and string literals (triple-quoted blocks and
# single/double-quoted) from Dart source on stdin, so code-construct greps see
# only real code (a `print(` inside a dartdoc example, a `'...'` string, or a
# triple-quoted code fixture is not a false positive).
strip_dart_comments_and_strings() {
  # The Dart source arrives on stdin. We cannot also feed Python its program on
  # stdin (`python3 - <<'PY'` would consume the heredoc as stdin and leave
  # sys.stdin empty), so the source is passed through the FLUVIE_SRC env var and
  # the program comes from the heredoc.
  local src
  src="$(cat)"
  FLUVIE_SRC="$src" python3 - <<'PY'
import re, os, sys
s = os.environ.get('FLUVIE_SRC', '')
s = re.sub(r'/\*.*?\*/', '', s, flags=re.DOTALL)   # block comments
s = re.sub(r'//[^\n]*', '', s)                       # line comments
s = re.sub(r"'''.*?'''", "''", s, flags=re.DOTALL)   # triple-single strings
s = re.sub(r'""".*?"""', '""', s, flags=re.DOTALL)   # triple-double strings
s = re.sub(r"'(\\.|[^'\\])*'", "''", s)              # single-quoted
s = re.sub(r'"(\\.|[^"\\])*"', '""', s)              # double-quoted
sys.stdout.write(s)
PY
}

# Voice gate for staged documentation/ markdown: no em/en-dashes, no
# marketing vocabulary (see CLAUDE.md "Documentation & the example lessons").
DOCS_BANNED_WORDS='seamless|robust|leverage|effortless|supercharge|game-changer|elevate|unleash|delve|blazing|world-class|best-in-class'

staged_docs_files() {
  git diff --cached --name-only --diff-filter=ACM -- 'documentation/*.md' 'documentation/**/*.md'
}

# Docs-lint: print each ```dart fence whose immediately-preceding non-blank line
# is NOT a `<!-- code-excerpt ... -->` directive (or the narrow
# `<!-- code-excerpt-ignore: ... -->` opt-out). The Markdown source arrives on
# stdin; offending fence line numbers (1-based) are written to stdout, so a
# caller fails the file when this prints anything. Four-backtick fences
# (````dart, which wrap a triple-backtick block) are intentionally skipped:
# their body is itself Markdown, not a snippet.
naked_dart_fences() {
  local src
  src="$(cat)"
  FLUVIE_SRC="$src" python3 - <<'PY'
import os, re, sys
lines = os.environ.get('FLUVIE_SRC', '').split('\n')
def is_open(line):
    t = line.rstrip()
    return t == '```dart' or t.startswith('```dart ')
i = 0
out = []
while i < len(lines):
    t = lines[i].rstrip()
    # A four-or-more-backtick fence wraps a Markdown block (which may itself
    # contain a ```dart line). Skip it whole, by its own closing run.
    quad = re.match(r'^(`{4,})', t)
    if quad:
        run = quad.group(1)
        i += 1
        while i < len(lines) and lines[i].rstrip() != run:
            i += 1
        i += 1
        continue
    if is_open(lines[i]):
        j = i - 1
        while j >= 0 and lines[j].strip() == '':
            j -= 1
        prev = lines[j] if j >= 0 else ''
        ok = re.match(r'^\s*<!--\s*code-excerpt(-ignore:)?', prev)
        if not ok:
            out.append(str(i + 1))
        # advance past the fence body to its close
        i += 1
        while i < len(lines) and lines[i].rstrip() != '```':
            i += 1
    i += 1
sys.stdout.write('\n'.join(out))
PY
}

# Max lines allowed per Dart file (file-size budget; see CLAUDE.md).
MAX_FILE_LINES=200

# Print staged added/copied/modified Dart files, one per line.
staged_dart_files() {
  git diff --cached --name-only --diff-filter=ACM -- '*.dart'
}
