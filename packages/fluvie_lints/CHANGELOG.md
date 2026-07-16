# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the versions follow [Semantic Versioning](https://semver.org/).

## [0.3.0] - 2026-07-16

Lockstep release with the rest of the workspace; replace this note with
the package changes, or leave it if there are none.

## [0.2.0] - 2026-07-06

### Changed

- The trigger rules (`cyclic_trigger`, `dangling_anchor`, `unused_anchor`)
  match the renamed `Trigger.whenEnds`, and the `deprecated_member`
  quick-fix notes point at the 0.2.0 names (`PhotoFrame`).

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

Lockstep release with the rest of the workspace; no functional changes.

## [0.1.4] - 2026-06-22

### Removed

- The `nondeterministic_random` lint rule, with its fixtures. Byte-identical
  determinism is no longer a Fluvie ground pattern, so the rule no longer ships.

## [0.1.3] - 2026-06-22

Lockstep release with the rest of the workspace; no changes to this package.

## [0.1.2] - 2026-06-21

Lockstep release with the rest of the workspace; no changes to this package.

## [0.1.0] - 2026-06-20

The first public release: the full ten-rule set.

### Added

- Anchor and trigger rules: `dangling_anchor`, `cyclic_trigger`, `unused_anchor`.
- Timing rules: `animation_exceeds_window`, `conflicting_keyframe_fields`,
  `relative_outside_scope` (conservative, no false positives).
- `deprecated_member`: drives migration off the old names, with quick-fixes.
- `layering` and `no_src_import`: enforce the layering law and the single barrel.
- Quick-fixes for `no_src_import`, `deprecated_member`, and `unused_anchor`.

[0.1.0]: https://github.com/SimonErich/fluvie/releases/tag/v0.1.0
