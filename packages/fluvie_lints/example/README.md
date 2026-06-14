# fluvie_lints example

Enable the rules in any package that uses Fluvie:

```yaml
# analysis_options.yaml
analyzer:
  plugins:
    - custom_lint
```

Then run them:

```sh
dart run custom_lint
```

The Dart files under `lib/` are fixtures: each one triggers a single rule and
carries an `// expect_lint:` marker showing what the rule catches (a dangling
anchor, a cyclic trigger, an unseeded `Random()`, a cross-package `src` import,
and so on). They double as the golden inputs for the rule tests.
