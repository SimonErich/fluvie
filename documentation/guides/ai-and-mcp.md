# AI and MCP

There are two ways to let a model direct Fluvie:

1. **Author from a prompt.** Describe the video you want; a model writes a Fluvie
   `VideoSpec`; Fluvie renders it. This is the [`fluvie_ai`](https://pub.dev/packages/fluvie_ai)
   package and the `fluvie generate` command.
2. **Hand Fluvie to an assistant.** Run the MCP server and an assistant like
   Claude can author and render videos for you, from inside your editor or chat.

The model runs only at authoring time. The spec it writes renders byte-identically
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

## The MCP server

[MCP](https://modelcontextprotocol.io) is the protocol assistants use to call
tools. The [`fluvie_mcp`](https://pub.dev/packages/fluvie_mcp) package is an MCP
server that exposes Fluvie as five tools:

| Tool | What it does |
| --- | --- |
| `generate_video` | Author from a prompt and render. |
| `edit_video` | Refine an existing spec with a plain-language change. |
| `render_video` | Render a spec you already have. |
| `render_composition` | Render a registered composition by key. |
| `get_video_spec_schema` | Fetch the spec schema to author against. |

The server does not render on its own. It points at a running Fluvie
[render API](rendering-on-a-server.md), which does the work. Point it at a local
`docker compose up` or at your hosted `api.fluvie.dev`.

### Run it

```sh
export FLUVIE_API_URL=https://api.fluvie.dev   # your render API
export FLUVIE_API_TOKEN=your-render-token       # if the API needs one

dart run fluvie_mcp          # stdio, for a local assistant
dart run fluvie_mcp --http   # HTTP, for a hosted endpoint (HOST, PORT, FLUVIE_MCP_TOKEN)
```

### Connect Claude Code

```sh
# local, over stdio
claude mcp add fluvie -- dart run fluvie_mcp

# remote, over HTTP
claude mcp add --transport http fluvie https://mcp.fluvie.dev/mcp \
  --header "Authorization: Bearer $FLUVIE_MCP_TOKEN"
```

Then ask in plain language: "make me a 6 second vertical title card on a dark
gradient, fade the headline in." The assistant calls `generate_video` and replies
with a link.

### Connect Claude Desktop

Add the server to your Claude Desktop config:

```json
{
  "mcpServers": {
    "fluvie": {
      "command": "dart",
      "args": ["run", "fluvie_mcp"],
      "env": {
        "FLUVIE_API_URL": "http://localhost:8080",
        "FLUVIE_API_TOKEN": "your-render-token"
      }
    }
  }
}
```

## Self-host everything

Run the whole pipeline yourself and point every tool at it. The
[render API](rendering-on-a-server.md) ships a `Dockerfile` and a
`docker-compose.yml`:

```sh
cp deploy/env/api.env.example deploy/env/api.env   # set API_TOKEN, and a provider key for server-side AI
docker compose -f deploy/docker-compose.yml up --build
```

Then run `fluvie_mcp --http` next to it with `FLUVIE_API_URL` pointing at the API.
If you set a provider key on the API, the `generate_video` and `edit_video` tools
work end to end; if not, the server renders specs and registered compositions and
returns a clear error for prompt-based calls.

## Where to next

- [Authoring with specs](authoring-with-specs.md): the spec format and the Dart API.
- [Rendering on a server](rendering-on-a-server.md): the render API in full.
- [`fluvie_mcp`](https://pub.dev/packages/fluvie_mcp) and [`fluvie_ai`](https://pub.dev/packages/fluvie_ai) on pub.dev.
