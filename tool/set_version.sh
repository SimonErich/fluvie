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

# Every in-repo package name, as an alternation for the constraint rewrite. Only
# directories that actually hold a pubspec count: a leftover artifact directory
# under packages/ (a stale .dart_tool or coverage dir from a package that was
# removed) shares its name with a real pub.dev dependency, and treating it as
# ours would rewrite that third-party constraint to our release version.
packages_alt="$(for d in packages/*/; do
  [[ -f "$d/pubspec.yaml" ]] && basename "$d"
done | paste -sd'|')"

changed=()
for pubspec in packages/*/pubspec.yaml; do
  grep -qE '^version:' "$pubspec" || continue # the workspace root has no version
  sed -i -E "s/^version:.*/version: ${version}/" "$pubspec"
  # Inter-package constraints track the release version so publish.yml's
  # `needs:` ordering can guarantee each dependent resolves against the version
  # published in the same run. Path deps (dev_dependencies) don't match.
  sed -i -E "s/^(  (${packages_alt}): )\^?[0-9][0-9A-Za-z.+-]*$/\1^${version}/" "$pubspec"
  stamp_changelog "$(dirname "$pubspec")/CHANGELOG.md"
  changed+=("$(basename "$(dirname "$pubspec")")")
done

# Example and in-repo apps carry the same constraints so a minor or major bump
# still resolves; they are not published, so only the constraint line moves.
# Every workspace member must be listed here: a member left pinned to the old
# version makes the whole workspace unresolvable, so `dart pub get` and
# `dart test` fail repo-wide rather than just in that app.
for pubspec in examples/*/pubspec.yaml apps/*/pubspec.yaml packages/*/example/pubspec.yaml; do
  [[ -f "$pubspec" ]] || continue
  sed -i -E "s/^(  (${packages_alt}): )\^?[0-9][0-9A-Za-z.+-]*$/\1^${version}/" "$pubspec"
done

# Version-bearing Dart constants that must track the release. The pubspec sed
# above never touches these, so without this step a bump would leave a stale
# `fluvie init` pin, render-cache key, or advertised MCP version behind. Guarded
# by lockstep tests in each package so a missed rewrite fails the gate.
sed -i -E "s/(const String fluvieRenderVersion = ')[^']*(';)/\1${version}\2/" \
  packages/fluvie/lib/src/rendering/encoding/content_hash.dart
sed -i -E "s/(const String (fluvieDependencyVersion|fluvieLintsDependencyVersion) = ')\^?[^']*(';)/\1^${version}\3/" \
  packages/fluvie_cli/lib/src/init_support.dart
sed -i -E "s/(const String _version = ')[^']*(';)/\1${version}\2/" \
  packages/fluvie_server/lib/src/app/server_runtime.dart

echo "Set ${#changed[@]} packages to ${version}: ${changed[*]}"
echo "Stamped a [${version}] section into each package CHANGELOG (idempotent)."
echo "Next: edit the CHANGELOG sections, commit, then create the GitHub Release for v${version}."
