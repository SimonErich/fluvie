# Contributing to Fluvie

Thanks for wanting to help. This page is the short version; the long version
lives in [documentation/contributing/](documentation/contributing/).

## Setup

```sh
git clone https://github.com/SimonErich/fluvie.git && cd fluvie
dart pub get                       # resolves the workspace root
dart run melos bootstrap           # resolves all packages
bash .githooks/install.sh          # installs the git hooks (required)
```

You need Flutter 3.44+, Dart 3.12+, and `ffmpeg` on your PATH for the
render-integration tests.

## The rules that get PRs merged

1. **Test first.** Every change starts with a failing test. No production code
   without one.
2. **The gate is green**: `CI=true dart run melos run gate` (format, analyze,
   custom_lint, tests, coverage ≥97%).
3. **Conventional Commits**, one concern per commit (`feat(timing): …`,
   `fix(rendering): …`). The commit-msg hook enforces the format.
4. **Small files**: ≤200 lines per production file, ≤80 lines per `build`.
   The pre-commit hook enforces this.
5. **Determinism is sacred**: no wall-clock, no unseeded randomness in render
   code. Goldens must be byte-stable; regenerate with
   `flutter test --update-goldens --tags golden` and review the PNG.
6. **Docs ship with features.** A new public API needs dartdoc; a new
   capability needs its page in `documentation/` (see the voice rules in
   [documentation/README.md](documentation/README.md)).
7. **One home per fake.** A fake that package consumers use in their own tests
   ships in `lib/src/fake/` and is exported from the barrel; a fake only this
   repository's tests use lives in `test/**/fakes/` next to its suite.

## Where things live

- `packages/fluvie` — the library. `packages/fluvie_lints` — custom lints.
- `packages/fluvie_cli` — the headless renderer. `examples/gallery/` — the 12 lessons.
- `examples/` — one small app per rendering path (CLI, desktop, mobile, browser, server) sharing `examples/kitten_kit`.
- `documentation/` — the guides, reference, and contributing pages.

## Reporting issues

Use the issue templates. For security reports, see [SECURITY.md](SECURITY.md).
