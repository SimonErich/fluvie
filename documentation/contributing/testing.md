# Testing guide

Every change starts with a failing test. This page explains the suites, how to
run them, and the fakes and goldens that keep them honest. Run the fast suite
before you commit:

```sh
melos run test
```

That runs the pure-Dart and Flutter unit tests across the workspace. It excludes
goldens and the tagged integration suites, so it is quick. The rest of this page
covers the slower suites and how each kind of test is written.

## Test first

Write the test, watch it fail for the right reason, then make it pass. No
production `.dart` file lands before its test exists. Red, green, refactor.

## The kinds of test

- **Unit tests** cover everything pure: `core`, `timing`, services, and math.
  They are the bulk. No real network and no real filesystem.
- **Golden tests** assert pixels through Alchemist. They carry the `golden` tag.
- **Integration tests** need a real resource and carry a tag for it: `ffmpeg`,
  `snapshot`, `wasm`, or `render`.

A plain `melos run test` excludes goldens and the tagged suites. CI gates the
tags per platform.

## Unit tests with mocktail and Riverpod

Mock a collaborator with mocktail and inject it through a Riverpod override.
A service is an abstract contract plus an implementation, wired by a provider, so
a test overrides the provider with a fake:

<!-- code-excerpt-ignore: illustrates the Riverpod override pattern with a test-only fake, not a runnable Fluvie API -->
```dart
final container = ProviderContainer(
  overrides: [frameCaptureServiceProvider.overrideWithValue(fakeCapture)],
);
```

Stub the fake's methods with `when(() => fake.method(any())).thenAnswer(...)`.
Register a fallback value for any non-primitive argument matched with `any()`:
`registerFallbackValue(Directory('/tmp'))`. No test touches the live network or a
real binary; media flows through an injected fake client or local fixtures.

## Golden tests with Alchemist

Goldens render at a fixed fps, a fixed seed, and DPR 1.0, so a frame is
reproducible. Seeded effects (`noise(seed)` / `random(seed)`) keep a golden
stable from run to run, so a diff means the output actually changed. Tag the
file `@Tags(['golden'])` and assert with `goldenTest`.

There are two flavors:

- **CI goldens** use the Ahem font and run on every platform.
- **Platform goldens** use real bundled fonts and run on the Linux baseline
  only, because font rasterization differs across platforms.

Run them and generate baselines:

```sh
melos run test:goldens                              # run the goldens
flutter test --update-goldens --tags golden         # regenerate baselines
```

Always review the PNG before you commit it. A golden diff is a deliberate
decision, not a rubber stamp.

## Integration suites

Each integration suite names what it needs in its tag, so CI can gate it where
the resource exists:

- `ffmpeg` needs the encoder on PATH (the 12-lesson render smoke, encode tests).
- `snapshot` needs a live headless renderer (the deferred Mermaid/WebView/Html
  transport).
- `render` and `wasm` need a full capture path or a web runtime.

These are not part of the fast gate. Run a tagged suite directly with
`flutter test --tags ffmpeg`.

## The web demo smoke test

The demo (`examples/gallery/`) has a headless-Chrome smoke test: it builds the web app,
serves it, and checks that the Flutter app boots, lays out, and logs no runtime
error. It guards the in-browser demo and runs in CI (the `web_smoke` job).

```sh
melos run web:smoke   # build, serve, and smoke-test the demo web app
```

It needs node, python3, and a Chrome binary (set `CHROME`). Pass `SKIP_BUILD=1`
to reuse an existing build.

## Coverage

The gate enforces 97% line coverage on every package under `packages/`. Run it
before you commit:

```sh
melos run coverage:check
```

Test behavior; ignore only lines that have none, with a reason on the same line.
The full policy is in [Coverage and the ignore policy](coverage.md).

## Doc snippets are tested too

Documentation Dart fences come from compiled sources under `examples/gallery/lib/`. Each
snippet file has a small test that builds it, so a doc never ships dead code.
Check the fences are in sync and free of naked Dart blocks:

```sh
melos run docs:snippets:check   # fences match their source
melos run docs:lint             # every dart fence has a code-excerpt directive
```

## Where to next

- [Coverage and the ignore policy](coverage.md): the 97% floor and when an
  ignore is allowed.
- [Contributing overview](overview.md): the workflow and the quality gate.
