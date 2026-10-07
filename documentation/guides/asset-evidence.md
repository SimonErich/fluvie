# Give AI evidence about your assets

Prepare a local catalog before asking a model to tell a story. The catalog binds
media facts, selected observations and transcripts to the source file's SHA-256.
Contact sheets record actual source frames and presentation times. Creating a
catalog does not call an authoring provider or invent visual descriptions.

```sh
fluvie assets ./assets --contact-sheets \
  --catalog-out build/fluvie/assets.catalog.json
fluvie generate "the life of my cat" \
  --catalog build/fluvie/assets.catalog.json --context-file assets/story.txt \
  --dart-out lib/cat_story.dart --no-render
```

The catalog and sheets remain in your project. Authoring verifies their source
and image hashes before using them; replacing an asset requires rebuilding its
catalog. A stale observation must not silently describe a different video.

Each sheet records its selected frames, source times, layout and toolchain
provenance. Its cache key covers those inputs and the source hash; generated
filenames are an implementation detail. Read the sheet path and `cacheKey` from
the catalog rather than deriving a filename from the video name or source hash.

## Supply observations with their certainty

Write a JSON array of selected observations. Asset names are exact paths relative
to the selected assets directory; times are source seconds. Keep facts separate
from your interpretation through `observed`, `inferred` or `unknown` certainty.

```json
[
  {
    "asset": "cat/playing.mp4",
    "fromSeconds": 1,
    "toSeconds": 2.5,
    "text": "The cat jumps onto the sofa.",
    "certainty": "observed"
  }
]
```

Save this as `assets/observations.json` and select it explicitly:

```sh
fluvie assets ./assets --catalog-out build/fluvie/assets.catalog.json \
  --contact-sheets --evidence observations.json
```

Observations record the selected file's provenance. Text alone does not imply
that the model viewed the footage. Uncertain cues should remain uncertain in the
authored story.

## Bind timestamped transcripts

Use an SRT or WebVTT file that already exists; Fluvie does not transcribe audio
automatically. Both sides of `--transcript` are relative to the assets directory
unless the caption path is absolute. Repeat it for several sources:

```sh
fluvie assets ./assets --catalog-out build/fluvie/assets.catalog.json \
  --transcript cat/playing.mp4=cat/playing.vtt
```

The catalog preserves source-second ranges, caption text and provenance. Selected
transcript files and observations are bounded; excessively large inputs fail
with an actionable message rather than entering an unlimited prompt.

## Let a vision provider inspect selected sheets

Contact-sheet creation is local. Uploading them to your selected provider requires
`--image-evidence` on authoring:

```sh
fluvie generate "the life of my cat" \
  --catalog build/fluvie/assets.catalog.json --image-evidence \
  --context-file assets/story.txt --no-render
```

Authoring selects at most four verified sheets, each up to 4 MiB. Use a
vision-capable provider and select an image-capable `--model` when needed;
Ollama's default `llama3.1` model is text-only. Adapters preserve selected cues
through their image transport, combining labeled sheets for a single-image
provider API when necessary. These cues remain available during repair attempts;
the model should not claim to see footage when only metadata or text was supplied.
Your provider receives the selected pictures. Use your own local inspection and
explicit observations when you want to keep pictures on your machine.

## Where to next

- [AI and MCP](ai-and-mcp.md): provider setup and code-preserving edits.
- [Create a video from local assets](../getting-started/authoring-with-assets.md): the complete workflow.
- [Review a video](reviewing-a-video.md): examine authored timing and sample output.
