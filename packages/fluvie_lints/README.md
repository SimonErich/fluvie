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
- `layering`, `no_src_import`: enforce the package layering law and the single
  public barrel.

The timing rules are conservative: they flag only forms they can decide
statically, so they do not produce false positives.

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
