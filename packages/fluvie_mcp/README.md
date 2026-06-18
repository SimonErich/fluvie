# fluvie_mcp

Let an AI assistant direct [Fluvie](https://pub.dev/packages/fluvie) for you. This
is a Model Context Protocol (MCP) server: point Claude (Desktop or Code) at it and
ask for a video in plain language. It authors a spec, renders it, and hands back a
download link.

[![pub package](https://img.shields.io/pub/v/fluvie_mcp.svg)](https://pub.dev/packages/fluvie_mcp)
[![license: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)

The rendering happens on a running Fluvie [render API](https://pub.dev/packages/fluvie_api),
so this package carries no Flutter or FFmpeg. It is a thin, tiny adapter between an
assistant and your renderer.

## Tools

| Tool | What it does |
| --- | --- |
| `generate_video` | Author a video from a prompt and render it. |
| `edit_video` | Refine an existing `VideoSpec` with a plain-language change. |
| `render_video` | Render a `VideoSpec` you already have. |
| `render_composition` | Render a composition registered in the project by key. |
| `get_video_spec_schema` | Fetch the `VideoSpec` JSON Schema to author against. |

## Run it

Set where your render API lives, then start the server.

```sh
export FLUVIE_API_URL=https://api.fluvie.dev   # your render API
export FLUVIE_API_TOKEN=your-render-token       # if the API needs one

# stdio (for a local assistant)
dart run fluvie_mcp

# or over HTTP (for a hosted endpoint)
dart run fluvie_mcp --http   # honours HOST, PORT, FLUVIE_MCP_TOKEN
```

## Connect Claude Code

```sh
# local, over stdio
claude mcp add fluvie -- dart run fluvie_mcp

# remote, over HTTP
claude mcp add --transport http fluvie https://mcp.fluvie.dev/mcp \
  --header "Authorization: Bearer $FLUVIE_MCP_TOKEN"
```

Then ask: "make me a 6 second vertical title card on a dark gradient, fade the
headline in." The assistant calls `generate_video` and replies with a link.

## Configuration

| Variable | Meaning | Default |
| --- | --- | --- |
| `FLUVIE_API_URL` | Render API base URL | `http://localhost:8080` |
| `FLUVIE_API_TOKEN` | Bearer token for the render API | none |
| `FLUVIE_MCP_TOKEN` | Bearer token required on the HTTP endpoint | none (open) |
| `HOST` / `PORT` | Where `--http` binds | `0.0.0.0` / `8080` |

## Documentation

See the Fluvie [AI and MCP guide](https://docs.fluvie.dev/guides/ai-and-mcp/).

## License

MIT. See [LICENSE](LICENSE).
