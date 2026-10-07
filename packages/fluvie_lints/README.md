# fluvie_lints

Custom analysis rules for the [Fluvie](https://pub.dev/packages/fluvie) video
library. They catch timing mistakes and layering violations as you type, with
quick-fixes where a fix is unambiguous.

[![pub package](https://img.shields.io/pub/v/fluvie_lints.svg)](https://pub.dev/packages/fluvie_lints)
[![license: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)

## The rules

- `dangling_anchor`, `cyclic_trigger`, `unused_anchor`: anchor and trigger wiring.
- `animation_exceeds_window`, `conflicting_keyframe_fields`, `relative_outside_scope`:
  statically decidable timing mistakes.
- `deprecated_member`: drives migration from the old names, with quick-fixes.
- `nondeterministic_video`: warns about `DateTime.now()`, `DateTime.timestamp()`,
  `Random()`, `Random(null)` and `Random.secure()` inside Fluvie `Video`, `Scene`
  or `FrameBuilder` construction. Use the authored frame, fixed input dates, or
  frame-derived seeds instead.
- `layering`, `no_src_import`: enforce the package layering law and the single
  public barrel.

The timing rules are conservative: they flag only forms they can decide
statically. The repeatability rule resolves SDK symbols, so unrelated classes
with the same names and ordinary application event handlers stay silent. It
does not inspect external helpers or prove a whole video deterministic. Pair it
with `fluvie review lib/my_video.dart --determinism` to compare sampled frames
after reverse seeks and a fresh mount.

Seeded mutable generators can still depend on evaluation order. Recreate the
generator from a seed derived from the authored frame, or use `ctx.noise(seed)`.
Intentional exceptions support Dart's `// ignore: nondeterministic_video` and
`// ignore_for_file: nondeterministic_video` directives.

## Use it

Add the dev dependencies and the plugin:

```sh
dart pub add --dev custom_lint fluvie_lints
```

```yaml
# analysis_options.yaml
analyzer:
  plugins:
    - custom_lint
```

Then run `dart run custom_lint`.

## Documentation

See the Fluvie [contributing guide](https://docs.fluvie.dev/contributing/overview/)
for how the rules fit the quality gate.

## License

MIT. See [LICENSE](https://opensource.org/licenses/MIT).
