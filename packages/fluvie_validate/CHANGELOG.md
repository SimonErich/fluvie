# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the versions follow [Semantic Versioning](https://semver.org/).

## [0.1.5] - 2026-06-23

### Added

- First published release. `FluvieCodeAnalyzer` resolves a snippet against
  `package:fluvie` and returns the compiler diagnostics plus the fluvie_lints
  rules as `FluvieDiagnostic`s, analyzing only and never running the code.
