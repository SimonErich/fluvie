# Package release checks

Published archives must work without the repository's parent directories.
Every publishable package therefore includes its local
`analysis_options.shared.yaml`. That generated file is an exact copy of the
root analysis policy, including the 100-column formatter, strict type checks
and Very Good Analysis rules. Package-specific documentation rules, fixture
exclusions and custom-lint plugins remain in `analysis_options.yaml`.

Edit the root policy, then run `dart tool/sync_package_analysis.dart --write`.
The `analyze:policy` gate and root tool tests check that every publishable
package has the current copy and declares the same Very Good Analysis version
as a direct development dependency. This duplication is deliberate: a published
package cannot include `../../analysis_options.yaml`, and adding just a local
formatter width does not prevent the formatter from following a broken include.
See Dart's [analysis configuration documentation](https://dart.dev/tools/analysis).

Run `bash tool/verify_packages.sh /absolute/path/to/flutter-sdk` to check the
core library, CLI and lint package with the selected release SDK. The current
release uses Flutter 3.47.2 / Dart 3.13.2. The script pins pana 0.23.19, supplies
explicit Dart and Flutter SDK paths, and saves JSON reports and logs to
`build/pana/`. A different report directory and package names may follow the SDK
argument. Pana analyzes an isolated copy of each package; no workspace root is
passed. The release-hardening evidence also verifies archives reconstructed
from the exact file list chosen by `dart pub publish --dry-run`.

Full scores are required for analysis, formatting, documentation, conventions
and platform support. The core and CLI require full dependency points too.
The lint package has one documented exception, described below. The JSON gate
checks each category separately, so that exception cannot hide another failure.
CI checks all three packages and retains the reports. Fresh-clone verification
fails on a package regression; it no longer swallows pana failures.

## Analyzer compatibility

As checked against pub.dev on 27 September 2026, the latest
[custom_lint_builder 0.8.1](https://pub.dev/packages/custom_lint_builder/versions/0.8.1)
and [custom_lint 0.8.1](https://pub.dev/packages/custom_lint/versions/0.8.1) require
`analyzer: ^8.0.0`. The builder also requires `custom_lint_core: 0.8.1` exactly.
Although [custom_lint_core 0.8.2](https://pub.dev/packages/custom_lint_core/versions/0.8.2)
supports analyzer 9, it cannot be substituted under that builder contract.
The upstream manifests are available from the pub.dev
[builder metadata](https://pub.dev/api/packages/custom_lint_builder/versions/0.8.1)
and [core metadata](https://pub.dev/api/packages/custom_lint_core/versions/0.8.2).

Keep `analyzer: ">=8.0.0 <9.0.0"` with `custom_lint_builder: ^0.8.1` until the
builder and host release a compatible upgrade. An isolated resolution probe
requiring analyzer 9 fails with that exact dependency conflict. Widening the
direct analyzer constraint would neither upgrade the transitive analyzer nor
prove API compatibility; overriding it would violate the lint protocol.

This constraint costs the lint package ten dependency-freshness points, so its
accepted current score is 150/160. Only that exact package and pair of
constraints receive the exception. An upgrade must remove or revise the
exception after resolving normally, running lint-rule and fix tests, checking
the validator's rule execution, and running the full workspace custom-lint gate.
Do not trade working editor diagnostics for a nominal dependency score.

Dry-run publishing is separate from release authorization. It does not upload
anything, and an uncommitted working tree produces an expected warning. Choose
the release version and review the changelog before an actual publication.
