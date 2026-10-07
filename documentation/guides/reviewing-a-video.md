# Review a video before sharing it

Run one command to check the Dart source, inspect the mounted composition and
capture representative pictures:

```sh
fluvie review lib/my_video.dart --json
```

Review executes your composition in the package-owned Flutter host. Use `validate`
when you only want static diagnostics without running the code. The review report
combines validation, actual mounted timing and resource facts, sample images and
the paths needed to examine the result. It is useful to a human reviewer and to
an assistant repairing a composition.

## Inspect the report visually

Review writes `index.html` beside `review.json`. Open it locally to inspect the
sample PNGs, diagnostics and provenance. The live [authoring workspace](authoring-workspace.md)
adds exact-frame seeking, before/after comparison and export controls.

## Review text and sound

Selected-frame review inspects laid-out Flutter paragraphs for overflow,
declared windows too brief for the text, and requested fonts absent from the
loaded font manifest. Findings include a frame or interval, a stable code,
an explanation and a remedy. Reading time uses three whitespace-separated
words per second plus 350 ms and is an advisory heuristic. Offstage and fully
transparent subtrees are skipped. Custom painters and rasterized text are not
inspected; font absence indicates portability risk rather than proven glyph
substitution.

Caption reading windows use the individual cue's interval, including when the
caption layer spans the whole video. The live workspace lists each finding and
its remedy; **Inspect frame** seeks to the finding on the reviewed source
revision. A source edit makes that request fail explicitly until you review the
new revision.

With `--render`, review also measures encoded audio. It reports silence below
-50 dB lasting at least 500 ms and peaks at or above -0.05 dBFS. Near-full-scale
peaks indicate clipping risk rather than proven distortion. These findings may
be intentional. Missing measurement inputs are explicitly unchecked.

```sh
fluvie review lib/my_video.dart --render --strict-quality \
  --allow-quality audio_silence --json
```

Normal quality findings are advisory. `--strict-quality` fails on warnings not
explicitly allowed. Allowed findings stay visible with their reason. Valid codes
are `text_overflow`, `text_too_brief`, `font_not_bundled`, `audio_silence` and
`audio_peak`. Other validation, determinism and output failures still fail review.

Strict quality also fails when an applicable encoded-audio measurement is
unavailable. An export with no audio stream is explicitly inapplicable. Ordinary
rendered reviews measure audio even without `--strict-decode`; that flag
separately checks decodability. `checksComplete` records whether applicable
measurements completed. Intentional finding exceptions never turn a failed
measurement into a pass.

## Choose the pictures to inspect

With no sample list, review selects representative positions. Use explicit
authored frame indexes for a transition or problem area:

```sh
fluvie review lib/my_video.dart --samples 0,15,29 \
  --out-dir build/fluvie/review --json
```

Choose indexes within your video's duration. Shared `--project`, entrypoint,
tooling and output-option flags work as they do for rendering. The report keeps
errors associated with their stage, resource and requested frame where available.

## Check seeking and fresh initialization

```sh
fluvie review lib/my_video.dart --determinism --json
```

With the managed capture cache disabled, review hashes the selected RGBA pictures
and performs two checks:

- `same_session_reverse_seek` captures the pictures in reverse order in the
  original session. It catches painted state that depends on seek history.
- `fresh_mount` unmounts the original tree, prepares a new session and captures
  the same pictures again. The managed adapter invokes your entry function again,
  so factory choices and widget initialization are checked. A custom host can
  pass `videoFactory` to `runFluvieRender`; without it, the same immutable video
  definition is remounted with fresh widget state.

The combined method is `reverse_seek_and_fresh_mount`. The report's `checks`
array gives separate outcomes and `factoryEvaluated` records whether the entry
was invoked again. Mismatches carry a stable `code`, their `check`, an authored
frame when applicable, expected/actual evidence and a remedy. Canvas, FPS and
duration changes receive `fresh_mount_changes_composition`; pixel differences
receive `fresh_mount_changes_pixels`. A factory or preparation failure receives
`fresh_mount_failed` with its cause. Original sample PNGs remain available even
when fresh preparation fails.

Review checks sampled frames in one host process. It does not reset process-wide
globals, inspect every frame or guarantee identity across Flutter engines,
platforms and fonts. Repeat independent renders when process initialization is
part of your inputs. Static validation also warns about obvious SDK clock and
unseeded random calls inside video construction through `nondeterministic_video`.

## Render and verify the final output

```sh
fluvie review lib/my_video.dart --render --strict-decode --json
```

`--render` produces an encoded artifact and compares readable output facts to the
resolved render intent, including audio-stream presence. A stream alone does
not establish audible sound or a suitable level. `--strict-decode` also asks
FFmpeg to decode the complete
output so corruption after the container header does not pass a probe-only check.
It requires `--render` and costs an additional decode. This verifies
decodability. Verification does not
judge the story, typography, framing or whether a picture is the one you intended;
inspect the samples and watch the result for those decisions.

For automation, `--json` returns the review report as JSON. `--machine` writes
JSON progress events followed by a final `event: "review"` report. The related
`inspect --machine` and `frame --machine` commands finish with `inspection` and
`frame` events; the frame event includes its index and output path.

## Where to next

- [Exporting your video](exporting-your-video.md): output settings and retained receipts.
- [The rendering surface](../reference/rendering-surface.md): custom adapters and cancellation.
- [Performance](../advanced/performance.md): caches and bounded native decoding.
