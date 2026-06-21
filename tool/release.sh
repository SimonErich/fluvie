#!/usr/bin/env bash
# Release helper: push the per-package pub.dev tags (and optionally the umbrella
# image tag), deriving every version from its pubspec so a tag can never drift
# from the version it publishes.
#
# Each `<pkg>-v<version>` tag triggers .github/workflows/publish.yml (pub.dev via
# OIDC); the umbrella `v<version>` tag triggers images.yml (container images).
# GitHub does NOT fire those workflows for tags pushed by the Actions
# GITHUB_TOKEN, so a release must be tagged from a real account: run this script
# locally from a green `main`.
#
# A package is tagged only when its pubspec version is not already on pub.dev, so
# unchanged packages are skipped and re-running after a partial release is safe.
#
# Usage:
#   tool/release.sh                       # dry run: show what a release would push
#   tool/release.sh --push                # push the new per-package pub.dev tags
#   tool/release.sh --push --images 0.1.2 # also push the umbrella image tag v0.1.2
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

push=0
images_version=""
while [ $# -gt 0 ]; do
  case "$1" in
    --push) push=1; shift ;;
    --images) images_version="${2:?--images needs a version, e.g. --images 0.1.2}"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

field() { awk -v k="$1" '$0 ~ "^" k ":" {print $2; exit}' "$2"; }

# Tags already on origin, fetched once (so a re-run never re-creates one).
remote_tags="$(git ls-remote --tags origin | sed 's#.*refs/tags/##; s/\^{}//' | sort -u)"
on_remote() { grep -qxF "$1" <<<"$remote_tags"; }

# Versions of <pkg> already on pub.dev; empty if the package is unpublished.
pub_versions() {
  curl -fsS "https://pub.dev/api/packages/$1" 2>/dev/null \
    | grep -oE '"version":"[^"]+"' | sed 's/"version":"//; s/"//g' | sort -u
}

to_push=()
for pubspec in packages/*/pubspec.yaml; do
  name="$(field name "$pubspec")"
  version="$(field version "$pubspec")"
  [ "$(field publish_to "$pubspec")" = "none" ] && continue
  # Only packages publish.yml actually triggers on can auto-publish to pub.dev.
  if ! grep -qE "^[[:space:]]*-[[:space:]]*\"?${name}-v" .github/workflows/publish.yml; then
    echo "skip   $name: default publish_to but no publish.yml trigger; it will not auto-publish"
    continue
  fi
  if ! published="$(pub_versions "$name")"; then
    echo "WARN   $name: could not reach pub.dev; skipping to avoid a wrong publish"
    continue
  fi
  if grep -qxF "$version" <<<"$published"; then
    echo "ok     $name $version already on pub.dev"
    continue
  fi
  tag="${name}-v${version}"
  on_remote "$tag" \
    && echo "wait   $tag already pushed; publish.yml should be running" \
    || { echo "NEW    $tag"; to_push+=("$tag"); }
done

if [ -n "$images_version" ]; then
  umbrella="v${images_version}"
  on_remote "$umbrella" \
    && echo "ok     $umbrella already on origin" \
    || { echo "NEW    $umbrella (container images)"; to_push+=("$umbrella"); }
fi

if [ ${#to_push[@]} -eq 0 ]; then
  echo "Nothing to push."
  exit 0
fi

if [ "$push" -ne 1 ]; then
  echo
  echo "Dry run. Re-run with --push to create and push: ${to_push[*]}"
  exit 0
fi

for tag in "${to_push[@]}"; do git tag "$tag"; done
git push origin "${to_push[@]}"
echo "Pushed: ${to_push[*]}"
