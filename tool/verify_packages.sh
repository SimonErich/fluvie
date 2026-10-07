#!/usr/bin/env bash
# Use the SDK selected for the release; never let a different PATH SDK run pana's children.
set -euo pipefail

PACKAGE_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_SDK="${1:?Usage: verify_packages.sh <flutter-sdk> [report-directory] [packages...]}"
PACKAGE_SDK="$(cd "$PACKAGE_SDK" && pwd)"
PACKAGE_REPORTS="${2:-$PACKAGE_REPO/build/pana}"
shift
if (($#)); then shift; fi
if (($# == 0)); then set -- fluvie fluvie_cli fluvie_lints; fi
PACKAGE_DART="$PACKAGE_SDK/bin/dart"
PACKAGE_SOURCE="${FLUVIE_PACKAGE_ROOT:-packages}"
export PATH="$PACKAGE_SDK/bin:$PATH"
export FLUTTER_ROOT="$PACKAGE_SDK"
mkdir -p "$PACKAGE_REPORTS"
PACKAGE_REPORTS="$(cd "$PACKAGE_REPORTS" && pwd)"
cd "$PACKAGE_REPO"

"$PACKAGE_DART" tool/sync_package_analysis.dart --check
"$PACKAGE_DART" pub global activate pana 0.23.19
for package in "$@"; do
  case "$package" in
    fluvie|fluvie_cli|fluvie_lints) ;;
    *) printf 'Unknown packaging gate target: %s\n' "$package" >&2; exit 64 ;;
  esac
  "$PACKAGE_DART" pub global run pana \
    --dart-sdk "$PACKAGE_SDK/bin/cache/dart-sdk" --flutter-sdk "$PACKAGE_SDK" \
    --json "$PACKAGE_SOURCE/$package" \
    >"$PACKAGE_REPORTS/pana-$package.json" 2>"$PACKAGE_REPORTS/pana-$package.log"
  "$PACKAGE_DART" tool/check_pana.dart "$PACKAGE_REPORTS/pana-$package.json"
done
