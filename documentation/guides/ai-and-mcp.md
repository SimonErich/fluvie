# AI and MCP

There are three ways to let a model direct Fluvie:

1. **Author from a prompt.** Describe the video you want; a model writes a Fluvie
   `VideoSpec`; the CLI writes readable Dart and renders that composition. This is
   the [`fluvie_ai`](https://pub.dev/packages/fluvie_ai) package and the
   `fluvie generate` command.
2. **Teach an assistant Fluvie.** Run the MCP server in docs mode and a coding
   assistant like Claude can search and read the Fluvie documentation as it writes
   your composition. No render backend needed.
3. **Hand Fluvie to an assistant.** Run the server in build mode and the assistant
   can author and render videos for you, end to end, from your editor or chat.

For prompt-to-spec authoring, the model runs at authoring time. The resulting
spec records the composition and timing; rendering it needs no authoring model.
Generated-media elements can still call their configured generator during
resource preparation. Keep their resolved assets to replay that input. The CLI
makes Dart the default editable artifact and retains the authoring spec beside
the output. Commit the composition and selected assets, diff edits, and render
again. See [authoring with specs](authoring-with-specs.md) for the companion format.

## Bring your own key

For a coding assistant working in a local Flutter project, start with
[Create a video from local assets](../getting-started/authoring-with-assets.md).
`fluvie docs --context` prints an offline guide matched to the installed CLI.
The MCP server also ships the canonical documentation inside its binary; docs
mode needs no repository checkout, website access, or special docs directory.
Set `FLUVIE_DOCS_DIR` to an existing Markdown directory only when you want to
override that corpus. A missing or empty override fails at startup with a clear
error. Public agents can discover the same corpus at
[llms.txt](https://docs.fluvie.dev/llms.txt) and
[llms-full.txt](https://docs.fluvie.dev/llms-full.txt).

We do not run an unmetered public endpoint for your renders. The hosted demo
gives you a small free quota to try; for anything beyond that you bring your own
key, or run a local model with no key at all. Your own key selects your provider
account; it does not keep prompts from that provider. A local model lets you
keep authoring requests on your machine. A server or proxy receives the requests
you route through it.

| Provider | `FLUVIE_AI_PROVIDER` | API key | Sees rendered frames |
| --- | --- | --- | --- |
| Claude (default) | `claude` | `ANTHROPIC_API_KEY` | yes |
| Gemini | `gemini` | `GEMINI_API_KEY` | yes |
| Mistral | `mistral` | `MISTRAL_API_KEY` | with a vision-capable model |
| Ollama (local) | `ollama` | none | with a vision-capable model |

| Variable | Default | What it does |
| --- | --- | --- |
| `FLUVIE_AI_PROVIDER` | `claude` | Select `claude`, `gemini`, `mistral`, or `ollama`. |
| `FLUVIE_AI_MODEL` | provider's default model | Override the model sent to the provider. |
| `FLUVIE_AI_ENDPOINT` | provider's default endpoint | Use an absolute HTTP(S) request URL, including its full path, for a local server or compatible proxy. |

Pass `--provider <name>` to `generate`/`edit` to override `FLUVIE_AI_PROVIDER`
for a single run; API keys always come from the environment. An endpoint override
keeps the selected provider's request format and API-key requirements. For
example, Ollama accepts `http://127.0.0.1:11434/api/chat`; a base origin or relative
path does not identify the full request endpoint.

Explicit image evidence is bounded to four references, at most 4 MiB each,
before provider transport. Single-image adapters receive a labeled composite
when several references are selected. Mistral and Ollama transport the original
selected images; the configured model must support images. These are transport
capabilities, not a guarantee that every model can interpret a picture.

## Author from a prompt

Install the CLI, set a provider and key, then generate:

```sh
dart pub global activate fluvie_cli

export FLUVIE_AI_PROVIDER=claude
export ANTHROPIC_API_KEY=sk-...

fluvie generate "a 6s vertical title card, dark gradient, fade-in headline" \
  --spec-out promo.fluvie.json --dart-out lib/promo.dart
```

Generation always writes Dart before capture. With no `--dart-out`, it selects
`lib/generated_video.dart`, then a numbered filename when that file already
exists. `--no-render` writes the code and spec for review without encoding.

Edit that Dart directly to preserve your custom widgets, imports and comments:

```sh
fluvie edit lib/promo.dart "make the headline yellow" --no-render
fluvie review lib/promo.dart --json
```

Dart edits use bounded exact-text patches with structural and compiler-feedback repairs, validate a sibling candidate with its
relative imports intact, and mount it for inspection before replacing the
original. Successful edits retain the original as `<file>.fluvie.bak`. Validation
failure leaves the original source unchanged. `--dart-out` and `--spec-out` are
for spec edits, not in-place Dart edits.

You can still refine a saved spec. Multimodal spec edits can include the current
rendered frame so the provider sees what it is changing:

```sh
fluvie edit promo.fluvie.json "make the headline yellow" --dart-out lib/promo.dart
```

Render a spec again with no model call at all:

```sh
fluvie render --spec promo.fluvie.json
```

`--out` optionally names the video; otherwise output goes to `build/fluvie/`.
`--dart-out` chooses the native composition filename and `--no-render` lets you review it
before capture. Use `fluvie assets ./assets --json` for original filenames,
media facts, fonts, and bounded story notes. Missing native tools are reported
without downloading; `--download-tools` opts into warming them for inventory.


Built-in generation inventories the project's `assets/` by default. Point
`--assets <directory>` at a different root, and provide narrative text through
`--context "<text>"` or `--context-file assets/story.txt` (repeatable, up to four
8,192-byte files). It supplies up to 100 sorted factual assets and at most 64 KiB
of total context. It does not implicitly read story text or infer visual content
from filenames. A coding assistant can inspect files with its own tools and pass
the facts or narrative it selects. A reusable catalog adds timestamped observations,
transcripts and local contact sheets; see [asset evidence](asset-evidence.md).

```sh
fluvie generate "the life of my cat" --context-file assets/story.txt \
  --dart-out lib/cat_story.dart --spec-out cat_story.fluvie.json --no-render
fluvie validate lib/cat_story.dart --json
fluvie preview lib/cat_story.dart
fluvie render lib/cat_story.dart --machine
```


## Flutter-style (real code) generation

`fluvie generate` already writes Flutter widget code. An external coding assistant
can author the full Flutter surface directly after reading the offline docs.
For a fresh project, the assistant reaches for the `init_project` tool, which returns
the starter composition, the dependencies, and the `fluvie init` command to
scaffold a project. What you get back is a composition file exposing a top-level
`Video build()`; preview it with `fluvie preview ./<file>.dart` and render it with
`fluvie render ./<file>.dart`. See
[Start a project](../getting-started/start-a-project.md).

Before rendering generated code, the assistant can check it with `validate_code`.
That runs static analysis only (it never executes the code) and returns the
diagnostics, so a typo or a disallowed import is caught before a render starts.

## Generate editable Dart from a prompt

The demo Playground turns a prompt into editable Flutter-style Dart. You type a
prompt in the AI Assistant, the browser sends only that text to the Fluvie server,
and the server authors a `VideoSpec` with its configured model. The server then
prints that spec to a Dart `Video build()` snippet and returns it. The snippet
lands in the editor, where you tweak it and press Render. The browser never holds
a provider API key in the default server-configured flow, because the model runs
server-side. A deployment may still require its own Fluvie authentication token.

Two pieces make this work, and you can use either on its own:

- The spec-to-Dart printer is `printVideoSpecJson(Map)` in
  [`fluvie_cli`](https://pub.dev/packages/fluvie_cli). Give it a serialized
  `VideoSpec`, get back the editable snippet. It is a pure transformation, so it
  never calls a model or renders. It is `@experimental` while the printed shape
  settles.
- The same transformation is the `spec_to_dart` MCP tool below.

The printed Dart is the same code the Playground shows. It uses the public barrel
only, so it compiles in a real project. See [the Playground](playground.md) for
the editor and [authoring with specs](authoring-with-specs.md) for the spec format.

## Run a local model (no key)

[Ollama](https://ollama.com) runs a model on your machine, so there is no API key
or per-request provider fee. After downloading a model, you can author offline:

```sh
ollama pull llama3.1
export FLUVIE_AI_PROVIDER=ollama
export FLUVIE_AI_MODEL=llama3.1
export FLUVIE_AI_ENDPOINT=http://127.0.0.1:11434/api/chat
fluvie generate "a calm 4s loop, soft gradient, one word fading in" --out loop.mp4
```

## The Fluvie server

[`fluvie_server`](https://pub.dev/packages/fluvie_server) is one binary that hosts
everything: the [render API](rendering-on-a-server.md), an
[MCP](https://modelcontextprotocol.io) server, and a documentation helper. Turn
each part on or off with an environment variable, so you install one thing instead
of wiring up three.

| Variable | Default | What it does |
| --- | --- | --- |
| `FLUVIE_ENABLE_API` | `true` | Mount the render API at `/v1`. |
| `FLUVIE_ENABLE_MCP` | `true` | Enable the MCP server (`/mcp` and `--stdio`). |
| `FLUVIE_ENABLE_DOCS` | `true` | Enable the documentation helper. |
| `FLUVIE_MCP_MODE` | `build` when a backend exists, else `docs` | What the MCP tools cover. |
| `FLUVIE_MCP_TOKEN` | unset | Bearer token required on `/mcp`. |

### Two MCP modes

**Docs mode** is the documentation helper. It exposes the docs tools and the
schema, needs no render backend, and is perfect for a coding assistant that writes
Fluvie code for you:

| Tool | What it does |
| --- | --- |
| `get_authoring_context` | Start with the versioned local assets and Flutter authoring guide. |
| `list_docs` | List every documentation page. |
| `search_docs` | Full-text search the documentation. |
| `get_doc` | Read one page in full. |
| `init_project` | Start a project or add a composition in real Flutter/Dart code. |
| `get_video_spec_schema` | Fetch the spec schema to author against. |

**Build mode** adds the render and authoring tools on top, so the assistant can
make the video, not just write the code. It needs a render backend (this server's
own API, or a remote one via `FLUVIE_API_URL`):

| Tool | What it does |
| --- | --- |
| `generate_video` | Author from a prompt and render. Returns the download URL and the printed Dart `code`. |
| `edit_video` | Refine an existing spec with a plain-language change. Returns the download URL and the printed Dart `code`. |
| `spec_to_dart` | Convert a `VideoSpec` (JSON) into an editable `Video build()` snippet. Pure: no model, no render. |
| `validate_code` | Statically check a `Video build()` snippet before rendering. |
| `render_video` | Render a spec you already have. |
| `render_composition` | Render a registered composition by key. |

`generate_video` and `edit_video` now return that printed Dart `code` next to the
download URL, so the assistant can hand you editable widget code and the finished
video in one reply. `spec_to_dart` does only the conversion, for when you have a
spec and want the code without a render.

### Run it

```sh
dart pub global activate fluvie_server

# Docs helper over stdio, for a local coding assistant (no backend needed):
FLUVIE_ENABLE_API=false fluvie_server --stdio

# The full server over HTTP (render API + MCP + docs on one port):
fluvie_server
```

### Connect Claude Code

```sh
# local docs helper, over stdio
claude mcp add fluvie -- env FLUVIE_ENABLE_API=false fluvie_server --stdio

# remote build server, over HTTP
claude mcp add --transport http fluvie https://mcp.fluvie.dev/mcp \
  --header "Authorization: Bearer $FLUVIE_MCP_TOKEN"
```

Then ask in plain language: "make me a 6 second vertical title card on a dark
gradient, fade the headline in." In build mode the assistant calls `generate_video`
and replies with a link; in docs mode it reads the docs and writes the composition
for you.

### Connect Claude Desktop

Add the server to your Claude Desktop config:

```json
{
  "mcpServers": {
    "fluvie": {
      "command": "fluvie_server",
      "args": ["--stdio"],
      "env": {
        "FLUVIE_API_URL": "http://localhost:8080",
        "FLUVIE_API_TOKEN": "your-render-token"
      }
    }
  }
}
```

## Self-host everything

The [render API guide](rendering-on-a-server.md) covers the Docker images in full.
The short version: one image, one env file.

```sh
cp deploy/env/server.env.example deploy/env/server.env   # set API_TOKEN, and a provider key for server-side AI
docker compose -f deploy/docker-compose.yml up --build
```

That serves `/v1` (render API), `/mcp` (MCP), and `/v1/docs` (docs) on one port. If
you set a provider key, `generate_video` and `edit_video` work end to end; if not,
the server still renders specs and registered compositions and returns a clear error
for prompt-based calls. For a tiny docs-only endpoint with no render toolchain, use
the slim `fluvie-server-docs` image.

## Host server-side AI without overspending

You can run the prompt path on your own key and still bound the cost. The hosted
demo does this: generation runs on the operator's key, pinned to a cheap model,
behind a per-IP rate limit and a daily quota.

Pin the model with `FLUVIE_AI_MODEL`. A small model keeps each call cheap:

```sh
export ANTHROPIC_API_KEY=sk-...
export FLUVIE_AI_MODEL=claude-haiku-...   # a cheap model for the public path
```

Then bound how often any one IP can spend your key. These apply to the LLM-cost
path only (prompt and edit); spec and code renders are not limited:

| Variable | Default | What it does |
| --- | --- | --- |
| `FLUVIE_AI_RATE_LIMIT` | `5` | Calls allowed per window, per IP. |
| `FLUVIE_AI_RATE_WINDOW` | `1m` | Width of the sliding window. |
| `FLUVIE_AI_DAILY_QUOTA` | `50` | Calls allowed per UTC day, per IP. |

A request over either limit returns HTTP `429` with a `Retry-After` header that
says how long to wait. Set a limit to `0` to switch that one check off.

## Where to next

- [Authoring with specs](authoring-with-specs.md): the spec format and the Dart API.
- [Rendering on a server](rendering-on-a-server.md): the server and its Docker images in full.
- [`fluvie_server`](https://pub.dev/packages/fluvie_server) and [`fluvie_ai`](https://pub.dev/packages/fluvie_ai) on pub.dev.
- [Server protocol](../reference/server-protocol.md): examples and tool arguments exported from the shipped registry.
- [Review a video](reviewing-a-video.md): validate, inspect, sample and verify the generated composition.

## Inspect and share an authoring run

[Authoring workspace](authoring-workspace.md) gives a human and an assistant the
same native frame, review and export session. [Portable projects](portable-projects.md)
preserve source, assets and dependency resolution for replay.
[Authoring benchmarks](authoring-benchmarks.md) measure real model calls,
preservation assertions and verified output separately from human visual review.

Multiline CLI prompts are encoded losslessly before reaching Flutter’s test
launcher. Compiler feedback uses the same transport, so line breaks and Unicode
do not become test-file arguments.
