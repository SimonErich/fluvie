# Git hooks

Committed, portable hooks installed via `core.hooksPath` (no per-clone copying).

## Install

```sh
bash .githooks/install.sh   # sets git config core.hooksPath .githooks
```

Run once after cloning. CI does not need them (it runs `melos run gate` directly).

## Hooks

### `pre-commit` (fast subset of the gate)
On staged Dart files:
- **grep-gate** — rejects `TODO`, `FIXME`, `print(`, ` as dynamic` (see `_lib.sh`).
- **size budget** — rejects any Dart file over `MAX_FILE_LINES` (200).
- **format** — `dart format --set-exit-if-changed` on staged files.

Whole workspace:
- **analyze** — `dart analyze --fatal-infos --fatal-warnings`.

`custom_lint` and the test suite are **not** in the hook (too slow per commit);
they run in **`melos run gate`** (the canonical pre-commit gate you run manually)
and in CI. The patterns/budget live in `_lib.sh` as the single source of truth.

### `commit-msg`
Enforces Conventional Commits on the subject line
(`<type>(<scope>): <subject>`; types: feat fix docs style refactor perf test
build ci chore revert) and warns if the subject exceeds 72 chars.

## Note on scope
The grep-gate inspects only `*.dart` files, so this README and the shell scripts
(which necessarily contain the forbidden words as patterns) are exempt.
