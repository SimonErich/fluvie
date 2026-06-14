<!-- Thanks for contributing to Fluvie. Keep one PR to one logical change. -->

## What this changes

<!-- A short summary of the change and why. Link any related issue. -->

## Checklist

- [ ] Tests added or updated first (red, then green), and they assert behavior.
- [ ] `CI=true melos run gate` is green (format, analyze, lint, coverage >= 97%).
- [ ] `melos run test:goldens` is green if I touched anything visual.
- [ ] Public members carry dartdoc; doc snippets flow from compiled sources.
- [ ] The layering law holds (dependencies point down only).
- [ ] Renders stay deterministic (no `DateTime.now()`, no unseeded `Random()`).
- [ ] One Conventional Commit per logical change.
