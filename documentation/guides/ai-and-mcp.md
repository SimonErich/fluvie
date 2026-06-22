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

We do not run a public endpoint that spends our API budget on your renders. You
bring your own key, or run a local model with no key at all. That keeps Fluvie
free for us to host and keeps your prompts private to you.

| Provider | `FLUVIE_AI_PROVIDER` | API key | Sees rendered frames |
| --- | --- | --- | --- |
| Claude (default) | `claude` | `ANTHROPIC_API_KEY` | yes |
| Gemini | `gemini` | `GEMINI_API_KEY` | yes |
| Mistral | `mistral` | `MISTRAL_API_KEY` | no |
| Ollama (local) | `ollama` | none | no |

`FLUVIE_AI_MODEL` overrides the model for any provider.

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
| `get_video_spec_schema` | Fetch the spec schema to author against. |

**Build mode** adds the render and authoring tools on top, so the assistant can
make the video, not just write the code. It needs a render backend (this server's
own API, or a remote one via `FLUVIE_API_URL`):

| Tool | What it does |
| --- | --- |
| `generate_video` | Author from a prompt and render. |
| `edit_video` | Refine an existing spec with a plain-language change. |
| `render_video` | Render a spec you already have. |
| `render_composition` | Render a registered composition by key. |

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

## Where to next

- [Authoring with specs](authoring-with-specs.md): the spec format and the Dart API.
- [Rendering on a server](rendering-on-a-server.md): the server and its Docker images in full.
- [`fluvie_server`](https://pub.dev/packages/fluvie_server) and [`fluvie_ai`](https://pub.dev/packages/fluvie_ai) on pub.dev.
