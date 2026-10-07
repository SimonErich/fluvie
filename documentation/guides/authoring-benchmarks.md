# Measure AI authoring

The authoring benchmark runs ordinary generate, edit and review commands against
a fixture project. It records model identity, prompts, readable Dart, preservation
assertions, mounted review evidence, verified exports and elapsed time.

```sh
fluvie benchmark suite.json --project fixture_project \
  --provider gemini --model gemini-2.5-flash --out-dir benchmark_run
```

Configure the chosen provider through the normal environment variables. A model
identity is required through `--model` or `FLUVIE_AI_MODEL`. `--fixture-mode`
labels a simulated provider explicitly. Reports from fakes are never real-model
evidence. A custom endpoint remains the caller's responsibility; the benchmark
does not authenticate a model's claimed identity.

From a checkout, create the reproducible synthetic fixture first:

```sh
python3 tool/benchmarks/create_fixture.py /tmp/fluvie-authoring-fixture --ffmpeg ffmpeg
fluvie benchmark tool/benchmarks/authoring_suite.json \
  --project /tmp/fluvie-authoring-fixture --provider gemini \
  --model gemini-2.5-flash --out-dir /tmp/fluvie-authoring-run
```

The helper uses `flutter create`, initializes the local package checkout, resolves
dependencies and generates geometry, a tone, story notes, captions and a custom
Flutter widget. It never calls a model. Choose a new destination for each fixture
and a new output directory for each benchmark run. Provider runs are opt-in and
use your configured provider account.

## Define a suite

```json
{
  "schemaVersion": 1,
  "cases": [
    {
      "id": "create",
      "action": "generate",
      "prompt": "Create a short video using assets/cat.png.",
      "requiredSourceText": ["assets/cat.png"]
    },
    {
      "id": "title",
      "action": "edit",
      "base": "create",
      "prompt": "Change the title to Milo's afternoon."
    }
  ]
}
```

Use 1–20 cases with unique lowercase identifiers. A `generate` case can include
`contextFiles` to supply explicit story files. An `edit` case names a previous
case through `base`, or a project-local Dart file through `source`.
The benchmark copies the source beside its original before editing, so relative
imports retain their meaning and the original authored file remains unchanged.
A `formats` case exports its base for square, reels and landscape.

`preserve` contains exact text that must survive an edit. `preserveRegions`
contains named `// #docregion name` blocks that must remain byte-for-byte equal,
including their markers. Use a region around custom widget code to detect an
unrelated rewrite. `requiredSourceText` checks exact asset or API references.
It does not establish whether the chosen image tells the intended story.

The repository's `tool/benchmarks/authoring_suite.json` covers creation from
synthetic image/clip/music assets, pacing, a custom Flutter widget, captions and
multiple formats. Its fixture includes a factual `story.txt` and captions; do not
describe synthetic geometric fixtures as photographs of a cat.

## Read the evidence

Each case retains `prompt.txt`, `before.dart` when applicable, `after.dart`,
command diagnostics, a model trace and its review/export files. `benchmark.json`
records every case, including failures. A missing base fails explicitly.
Edit cases must change source and preserve their selected regions.

The default checks the full rendered output and selected-frame repeatability.
Use `--frames N` for a bounded draft and record that prefix as the measurement
scope. Timings include authoring, validation and review; they are not pure
model-inference latency. The case clock starts after CLI startup and excludes
fixture provisioning. Raw traces record per-attempt provider latency.

Visual quality is always `requires_human_review`. Watch the video and inspect
its frames. Codec verification, a preserved class and a correct asset string
cannot establish storytelling, framing or visual polish.

## Trace and repair Dart edits

```sh
fluvie edit lib/my_video.dart "Shorten the opening" --no-render \
  --ai-trace build/fluvie/opening-edit.trace.json
```

`--ai-trace` on generate/edit explicitly retains prompts, replies, repair turns
and provider-attempt latency. Transport credentials and headers are excluded;
the trace can contain the authored source and selected private asset context.
Keep it with the project's review evidence and select what to publish.

`DartEditService` is the package API for exact edits. It requests a bounded edits
object, validates unique non-overlapping original ranges through the same pure
validator used by the CLI, and repairs malformed replies within three attempts
by default. The CLI also makes at most two compiler-feedback repairs against the unchanged
original source. Each author request has at most three structural attempts, for
at most nine provider attempts per edit. Operational mount failures and concurrent
source changes stop publication. Static analysis and mounted validation happen
before source publication. Repair traces are kept alongside the initial trace. `RecordingAiClient` supplies the same evidence seam to custom hosts.

The installed CLI supplies the current API cheat sheet and relevant canonical
guides to Dart edits, capped at 32 KiB of UTF-8. Caption requests include compiled
`Captions.fromSrt` and `CaptionStyle` examples. Documentation version and content
digest identify the supplied API context. Exact-match failures identify the
offending original text and ask for enough surrounding Dart to select one range.
Source, patch replies and patched output are each limited to 256 KiB of UTF-8.
Multiline prompts are transported losslessly through the managed Flutter host.

## Publish a recorded demonstration

The local marketing site includes a recorded five-case Gemini run and eight
exports at `/authoring`. Its geometric fixtures, prompts, original and edited
Dart, native-frame posters, videos and portable bundle are downloadable. The
page labels its provider and the scope of its automated checks.

From a checkout, publish your own successful real-provider report:

```sh
entry=$(python3 -c 'import json; print(json.load(open("/tmp/fluvie-authoring-run/benchmark.json"))["cases"][0]["sourcePath"])')
fluvie bundle create "$entry" \
  --out /tmp/fluvie-authoring-project.fluvie.zip
node tool/benchmarks/publish_evidence.mjs \
  /tmp/fluvie-authoring-run/benchmark.json /tmp/fluvie-authoring-project.fluvie.zip
node tool/benchmarks/verify_evidence.mjs
```

The command selects the creation case's `sourcePath` from this five-case suite.
The bundle must contain the recorded case sources.
The publisher checks their hashes against the bundle, verifies receipts and
matches each poster's decoded RGBA pixels to a sampled native frame. The site
build checks the published bytes and displayed Dart against the recorded
identities. Provider traces stay private unless you explicitly select them;
publication copies a sanitized report. These checks establish the recorded
workflow and artifact identities. Review storytelling and layout yourself.

## Where to next

- [AI and MCP](ai-and-mcp.md): provider setup and installed documentation.
- [Authoring workspace](authoring-workspace.md): inspect the result in one session.
- [Portable projects](portable-projects.md): share replayable evidence.
