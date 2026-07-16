# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the versions follow [Semantic Versioning](https://semver.org/).

## [0.3.1] - 2026-07-16

Lockstep release with the rest of the Fluvie workspace.

## [0.3.0] - 2026-07-16

Lockstep release with the rest of the Fluvie workspace.

## [0.2.0] - 2026-07-06

### Changed

- The `custom_lint_builder` constraint widened from a pin to a range so the
  package publishes cleanly.
- The analyzer surface tracks the renamed `Trigger.whenEnds`.

## [0.1.10] - 2026-06-24

Lockstep release; no changes to this package since 0.1.9.

## [0.1.9] - 2026-06-23

Lockstep maintenance release; demo (mobile layout) and CI fixes only, no library changes since 0.1.8.

## [0.1.8] - 2026-06-23

Lockstep maintenance release; demo and deploy fixes only, no library changes since 0.1.6.

## [0.1.7] - 2026-06-23

Lockstep maintenance release; demo and deploy fixes only, no library changes since 0.1.6.

## [0.1.6] - 2026-06-23

Lockstep maintenance release; no functional changes since 0.1.5.

## [0.1.5] - 2026-06-23

### Added

- First published release. `FluvieCodeAnalyzer` resolves a snippet against
  `package:fluvie` and returns the compiler diagnostics plus the fluvie_lints
  rules as `FluvieDiagnostic`s, analyzing only and never running the code.
