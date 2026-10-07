# Review Flutter SDK golden changes

Keep the pixel comparator exact when upgrading Flutter. First prove a failure
is fresh and that its master matches the current reference. Retained
`test/**/failures` images can predate a successful reference update.

## Flutter 3.47.2 compatibility review

The Studio baseline run on Flutter 3.47.2 and Dart 3.13.2 found nine existing
fixtures failing in both Linux and blocked-text CI variants. The relevant
rounded-border sources and fixtures were unchanged. Obers UI still resolved
to git `990286c9`; Alchemist remained 0.14.0. This was not a redesigned screen
or a local Obers theme change.

CI now pins the same Flutter 3.47.2 renderer. The provenance test
`python tool/test/studio_sdk_baseline_test.py` rejects a mismatched CI SDK,
nonportable reference paths, changed accepted hashes or a nonzero comparator
tolerance. Older renderer baselines are not claimed to match these references.

Two separately captured runs of each variant produced identical test PNG
bytes. Every captured master matched its current reference SHA-256. Full Linux
captures and isolated differences were inspected at native resolution. The
differences were confined to the existing rounded border fringes; text,
interiors and layout did not move. A signed-distance audit of the reviewed
rounded rectangles found no changed pixel more than 3px from those borders.
That geometric audit is not a comparison tolerance, an ignored region or a
permission to accept future differences.

Native rounded-edge rasterization drift is the evidence-supported inference.
An old/new engine rendering bisection was not executed, so no particular
upstream renderer commit is attributed. Historical timeline captures from July
were excluded: they used superseded masters and did not establish a current
timeline regression.

| Fixture | Linux changed pixels | CI changed pixels | Maximum channel delta | Reviewed geometry |
| --- | ---: | ---: | ---: | --- |
| wave2_text_scene | 95 | 95 | 7 | Rounded Box card border |
| gradient_editor | 200 | 209 | 35 | Stop strip and color field borders |
| spectrum_color_picker | 264 | 404 | 34 | Six palette swatch borders |
| inspector_shell | 315 | 312 | 21 | Code card and rounded badges |
| playground_idle | 118 | 115 | 21 | Code card and language badge |
| start_first_run | 450 | 450 | 87 | Tips and template card corners |
| start_returning | 804 | 802 | 87 | Recent glyph and template borders |
| start_samples_open | 43 | 43 | 35 | Unoccluded template corners |
| start_compact | 46 | 46 | 85 | Tips card top corners |

Exact paths, dimensions, previous/accepted PNG hashes and audited geometry are
recorded in `tool/baselines/flutter_3_47_2_golden_migration.json`. This report
records an independently reviewed migration of exactly 18 existing references.
Post-update verification passed twice without enabling reference updates:
all eight package runs exited zero with fresh successful terminal JSON events,
no JSON errors and unchanged accepted reference hashes. These runs covered the
six exact files below and both Linux/CI variants. The complete repository gate
subsequently passed twice with fresh external runtimes: formatting, fatal
analysis, custom lint, 20 successful Flutter batch reports, four successful
Dart package reports, 70 root-tool tests and all 11 required coverage targets
above 97% per pass. Each report was independently checked for successful
terminal JSON and absence of errors. Interrupted and disk-full retries were
not counted.
This accepts the pre-redesign Fluvie test baseline, not the local Obers tree
or any redesigned application screen.
Do not update a directory of unrelated goldens or change the comparator.

## Reproduce the review

Run each exact file twice, once per variant, using a private temporary runtime
and a fresh JSON reporter. Save each variant's failure captures before the
next variant overwrites the shared failure filenames.

```sh
TMPDIR='<owned runtime>' flutter test '<exact test file>' --tags golden \
  --plain-name 'variant: Linux' --file-reporter 'json:<fresh Linux report>'
TMPDIR='<owned runtime>' flutter test '<exact test file>' --tags golden \
  --plain-name 'variant: CI' --file-reporter 'json:<fresh CI report>'
```

The six files are `packages/fluvie/test/serialization/goldens_wave2_test.dart`,
the editor's `goldens_gradient_editor_test.dart` and
`goldens_spectrum_picker_test.dart`, the gallery's `goldens_shell_test.dart` and
`playground_golden_test.dart`, and `apps/slides/test/goldens_start_test.dart`.
Run from the owning package. A fresh completed failure report is the expected
pre-migration result; it is not a passing gate.

After review, migrate only the individually accepted reference paths. Run the
same exact files twice without updates, then run the complete repository gate.
The Studio suite runner requires a fresh successful terminal JSON event as
well as process exit zero before publishing merged coverage. A terminated
Flutter process can return zero despite incomplete tests; that is not success.

This baseline review supplies no feature completion or 23-board Studio pixel
parity claim. Those require separate screenshots and real feature journeys.

## Where to next

Read [the coverage policy](coverage.md) and
[the release verification guide](editor-release-verification.md).
