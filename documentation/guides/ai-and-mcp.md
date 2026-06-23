# AI and MCP

There are three ways to let a model direct Fluvie:

1. **Author from a prompt.** Describe the video you want; a model writes a Fluvie
   `VideoSpec`; Fluvie renders it. This is the [`fluvie_ai`](https://pub.dev/packages/fluvie_ai)
   package and the `fluvie generate` command.
2. **Teach an assistant Fluvie.** Run the MCP server in docs mode and a coding
   assistant like Claude can search and read the Fluvie documentation as it writes
   your composition. No render backend needed.
3. **Hand Fluvie to an assistant.** Run the server in build mode and the assistant
   can author and render videos for you, end to end, from your editor or chat.

The model runs only at authoring time. The spec it writes renders the same way
every time after that, with no model in the loop. The spec is the artifact: commit
it, diff it, re-render it. See [authoring with specs](authoring-with-specs.md) for
the spec format and the Dart API.

## Bring your own key

We do not run an unmetered public endpoint for your renders. The hosted demo
gives you a small free quota to try; for anything beyond that you bring your own
key, or run a local model with no key at all. Your own key keeps Fluvie cheap for
us to host and keeps your prompts private to you.

| Provider | `FLUVIE_AI_PROVIDER` | API key | Sees rendered frames |
| --- | --- | --- | --- |
| Claude (default) | `claude` | `ANTHROPIC_API_KEY` | yes |
| Gemini | `gemini` | `GEMINI_API_KEY` | yes |
| Mistral | `mistral` | `MISTRAL_API_KEY` | no |
| Ollama (local) | `ollama` | none | no |

`FLUVIE_AI_MODEL` overrides the model for any provider. Pass `--provider <name>`
to `generate`/`edit` to override `FLUVIE_AI_PROVIDER` for a single run; API keys
always come from the environment.

## Author from a prompt

Install the CLI, set a provider and key, then generate:

```sh
dart pub global activate fluvie_cli

export FLUVIE_AI_PROVIDER=claude
export ANTHROPIC_API_KEY=sk-...

fluvie generate "a 6s vertical title card, dark gradient, fade-in headline" \
  --out promo.mp4 --spec-out promo.fluvie.json
```

Refine a saved spec by describing the change. On an edit, the current frame is
sent along so a multimodal provider can see what it is changing:

```sh
fluvie edit promo.fluvie.json "make the headline yellow" --out promo.mp4
```

Render a spec again with no model call at all:

```sh
fluvie render --spec promo.fluvie.json --out promo.mp4
```

## Flutter-style (real code) generation

Sometimes you want real Flutter widget code in your repo, not a JSON spec. Ask
for it in those words: "make me a Fluvie video in Flutter style" or "give me the
real Dart code." The assistant reaches for the `init_project` tool, which returns
the starter composition, the dependencies, and the `fluvie init` command to
scaffold a runnable project. See [Start a project](../getting-started/start-a-project.md).

Before rendering generated code, the assistant can check it with `validate_code`.
That runs static analysis only (it never executes the code) and returns the
diagnostics, so a typo or a disallowed import is caught before a render starts.

## Generate editable Dart from a prompt

The demo Playground turns a prompt into editable Flutter-style Dart. You type a
prompt in the AI Assistant, the browser sends only that text to the Fluvie server,
and the server authors a `VideoSpec` with its configured model. The server then
prints that spec to a Dart `Video build()` snippet and returns it. The snippet
lands in the editor, where you tweak it and press Render. The browser never holds
an API key, because the model runs server-side.

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

[Ollama](https://ollama.com) runs a model on your machine, so there is no key and
no cost. This is the easiest way to try authoring offline:

```sh
ollama pull llama3.2
export FLUVIE_AI_PROVIDER=ollama
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
