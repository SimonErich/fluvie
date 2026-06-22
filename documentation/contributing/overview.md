# Contributing overview

This page is the workflow: how a change moves from a failing test to a merged
commit. The rule that gates everything is one command. Run it before you commit:

```sh
CI=true melos run gate
```

The gate runs format, analyze, lint, and the coverage check. All four must be
green. Never leave the tree broken. The rest of this page explains each step and
the rules around it.

## Set up the workspace

Clone the repo and resolve the workspace, then install the hooks:

```sh
git clone https://github.com/SimonErich/fluvie.git && cd fluvie
dart pub get                  # resolves the workspace root
melos bootstrap               # resolves all packages
bash .githooks/install.sh     # installs the git hooks (required)
```

You need Flutter 3.44+, Dart 3.12+, and `ffmpeg` on your PATH for the
render-integration tests.

## Test first, always

Every change starts with a failing test. No production `.dart` file lands before
its test exists and has failed for the right reason. Red, then green, then
refactor. See the [Testing guide](testing.md) for the suites and fakes.

## The quality gate

The gate is four steps, each its own melos script:

- `melos run format` checks `dart format` left nothing to change.
- `melos run analyze` runs `dart analyze` with `--fatal-infos` and
  `--fatal-warnings`, so an info is a failure.
- `melos run lint --no-select` runs the custom lints (`dart run custom_lint`).
- `melos run coverage:check` enforces the 97% line-coverage floor.

Goldens run separately with `melos run test:goldens` on the Linux baseline. Run
`melos` non-interactively with `CI=true` to avoid the prompt path.

## The layering law

Dependencies point down only, inside `packages/fluvie/lib/src/`:

```text
core            pure Dart: Time, Keyframe, enums, Defaults, contracts
  ^
timing          TimeScope, frame resolution, the trigger/anchor resolver
  ^
features        rendering, animation, composition, elements, media, audio, theme
  ^
diagnostics     the inspector model and timeline table; nothing depends on it
```

`core` depends on nothing but Flutter math types. `timing` depends only on
`core`. A feature may depend on `core` and `timing`, never on `diagnostics`.
Nothing imports another package's `src/`. The `layering` and `no_src_import`
custom lints enforce all of this, so a violation fails `melos run lint`.

A forward dependency goes through an interface in the lowest stable layer, with a
fake for tests and the real implementation injected through a Riverpod provider.

## Capture is headless

In capture mode the frame is the only clock: no wall-clock and no async work
inside a frame, and media is pre-resolved before the loop. For effects, prefer
seeded `noise(seed)` and `random(seed)` so a golden stays stable run to run.
Fluvie does not guarantee byte-identical output across machines or encoders.
Regenerate goldens with `flutter test --update-goldens --tags golden` and review
the PNG.

## Code standards

- One primary public type per file. No `utils.dart` dumping grounds.
- 200 lines per production file, 80 lines per widget `build`. The pre-commit
  hook enforces the file budget.
- Every public member of `packages/fluvie` carries dartdoc.
- No `TODO`, `FIXME`, `print`, or unjustified `dynamic`.
- Page width 100, trailing commas required.
- A new public API needs its dartdoc and its documentation page, in the same
  change. Docs snippets come from compiled sources, never hand-typed; see the
  voice rules in [the documentation index](../index.md).

## Commits

Use Conventional Commits, one concern per commit (`feat(timing): …`,
`fix(rendering): …`). Bundle nothing unrelated. The commit-msg hook enforces the
format.

## Where to next

- [Testing guide](testing.md): the suites, the tags, and the fakes.
- [Coverage and the ignore policy](coverage.md): the 97% floor and when an
  ignore is allowed.
