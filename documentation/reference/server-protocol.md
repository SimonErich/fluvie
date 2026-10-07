# Server protocol

These examples are exported from the HTTP request serializer, server parser and MCP tool registry. Run a configured Fluvie server first, then set `FLUVIE_API_URL` and `FLUVIE_API_TOKEN`. The token authenticates to your Fluvie server; the server configures its authoring provider separately.

## HTTP render request

```sh
curl -X POST "$FLUVIE_API_URL/v1/renders" \
  -H "Authorization: Bearer $FLUVIE_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{
  "prompt": "A 4-second teal title card saying Hello, Fluvie.",
  "options": {
    "format": "mp4",
    "aspect": "reels"
  }
}'
```

The server returns HTTP 202 and a job. Poll the job URL in the `Location` header until it succeeds, then read its video download URL. A prompt request requires a configured authoring provider. Use a code, spec or registered key request when the composition is already authored.

## MCP tool call

Initialize your MCP session and send this `tools/call` message through the configured stdio or HTTP transport.

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "generate_video",
    "arguments": {
      "prompt": "A 4-second teal title card saying Hello, Fluvie.",
      "format": "mp4",
      "aspect": "reels"
    }
  }
}
```

## Render tools

| Tool | Arguments | Purpose |
| --- | --- | --- |
| `generate_video` | `prompt` (required); `aspect`: `reels`, `square`, `landscape`, `portrait45`; `format`: `mp4`, `gif`, `transparent`; `provider` | Author a Fluvie video from a natural-language prompt and render it. Returns a download URL. Use this only when a prompt is all you have: it authors a JSON VideoSpec first. If you already hold a VideoSpec, use render_video; if the project registers the composition by key, use render_composition; if the user asks for real Flutter/Dart widget code or to start a project, use init_project instead. |
| `edit_video` | `base` (required); `change` (required); `aspect`: `reels`, `square`, `landscape`, `portrait45`; `provider` | Refine an existing Fluvie VideoSpec with a natural-language change, then render it. Returns a download URL. |
| `validate_code` | `code` (required) | Statically check Fluvie Dart code (a top-level `Video build()` written in real Flutter widget code) before rendering. Returns analyzer diagnostics; it never runs the code. Use it to verify the format of a Flutter-style / real-code composition before you render or scaffold it. |
| `render_video` | `spec` (required); `aspect`: `reels`, `square`, `landscape`, `portrait45`; `format`: `mp4`, `gif`, `transparent` | Render a Fluvie VideoSpec (JSON) you already hold to a video. Returns a download URL. No model runs: the spec renders as-is. From a prompt use generate_video; from a registered key use render_composition. |
| `render_composition` | `key` (required); `aspect`: `reels`, `square`, `landscape`, `portrait45`; `format`: `mp4`, `gif`, `transparent` | Render a composition registered in the render project by its key (for example "demo" or a lesson key). Returns a download URL. For a JSON VideoSpec use render_video; from a prompt use generate_video. |
| `get_video_spec_schema` | none | Fetch the Fluvie VideoSpec JSON Schema so you can author valid specs. |
| `spec_to_dart` | `spec` (required) | Convert a Fluvie VideoSpec (JSON) into an editable, Flutter-style Dart `Video build()` snippet — the same code the Playground shows. A pure transformation: it never calls an LLM or renders. Use it to turn an authored or hand-written spec into real widget code a user can edit. |

## Where to next

- [AI and MCP](../guides/ai-and-mcp.md): configuration and docs-mode tools.
- [Rendering on a server](../guides/rendering-on-a-server.md): hosting and job lifecycle.
