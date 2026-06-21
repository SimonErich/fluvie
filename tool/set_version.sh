#!/usr/bin/env bash
# Set every package to one version for a lockstep release. pub.dev publishing and
# the container images both key off a single umbrella tag `v<version>`, so all
# packages share that version.
#
#   tool/set_version.sh 0.1.2
#
# Then update the CHANGELOGs, commit, and create the GitHub Release for `v0.1.2`.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

version="${1:-}"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?$ ]]; then
  echo "usage: tool/set_version.sh <version>   e.g. tool/set_version.sh 0.1.2" >&2
  exit 2
fi

changed=()
for pubspec in packages/*/pubspec.yaml; do
  grep -qE '^version:' "$pubspec" || continue # the workspace root has no version
  sed -i -E "s/^version:.*/version: ${version}/" "$pubspec"
  changed+=("$(basename "$(dirname "$pubspec")")")
done

echo "Set ${#changed[@]} packages to ${version}: ${changed[*]}"
echo "Next: update CHANGELOGs, commit, then create the GitHub Release for v${version}."
