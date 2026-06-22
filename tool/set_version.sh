#!/usr/bin/env bash
# Set every package to one version for a lockstep release. pub.dev publishing and
# the container images both key off a single umbrella tag `v<version>`, so all
# packages share that version.
#
#   tool/set_version.sh 0.1.2
#
# This bumps every package pubspec AND stamps a dated section into each package
# CHANGELOG. pub.dev rejects a publish whose CHANGELOG omits the current version
# (`dart pub publish` exits 65), so the stamp keeps the lockstep publish green
# even for packages with no changes. Edit the stamped sections with real notes,
# then commit and create the GitHub Release for `v<version>`.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

version="${1:-}"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?$ ]]; then
  echo "usage: tool/set_version.sh <version>   e.g. tool/set_version.sh 0.1.2" >&2
  exit 2
fi

today="$(date +%F)"

# Insert a new version section above the most recent one. Idempotent: a CHANGELOG
# that already mentions this version is left untouched.
stamp_changelog() {
  local changelog="$1"
  [[ -f "$changelog" ]] || return 0
  grep -qF "## [${version}]" "$changelog" && return 0
  awk -v ver="$version" -v today="$today" '
    !stamped && /^## \[/ {
      print "## [" ver "] - " today
      print ""
      print "Lockstep release with the rest of the workspace; replace this note with"
      print "the package changes, or leave it if there are none."
      print ""
      stamped = 1
    }
    { print }
  ' "$changelog" > "$changelog.tmp" && mv "$changelog.tmp" "$changelog"
}

changed=()
for pubspec in packages/*/pubspec.yaml; do
  grep -qE '^version:' "$pubspec" || continue # the workspace root has no version
  sed -i -E "s/^version:.*/version: ${version}/" "$pubspec"
  stamp_changelog "$(dirname "$pubspec")/CHANGELOG.md"
  changed+=("$(basename "$(dirname "$pubspec")")")
done

echo "Set ${#changed[@]} packages to ${version}: ${changed[*]}"
echo "Stamped a [${version}] section into each package CHANGELOG (idempotent)."
echo "Next: edit the CHANGELOG sections, commit, then create the GitHub Release for v${version}."
