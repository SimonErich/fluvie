# fluvie_server

One self-hostable server for the full AI power of [Fluvie](https://fluvie.dev): the
render API, AI authoring, the MCP server, and a documentation helper, all in one
binary. Enable the parts you want with environment variables; install one image,
not three services.

## Libraries

- `package:fluvie_server/client.dart` — the web-safe render client (`http` only),
  for a Flutter app on web, mobile, or desktop.
- `package:fluvie_server/server.dart` — the `dart:io`/`shelf` server.

## Run it

```sh
dart run packages/fluvie_server/bin/fluvie_server.dart
```

The render API listens on `HOST:PORT` (default `0.0.0.0:8080`). See the
[server guide](https://docs.fluvie.dev/guides/rendering-on-a-server) and the
[AI and MCP guide](https://docs.fluvie.dev/guides/ai-and-mcp) for configuration,
the MCP modes, and Docker images.

## AI cost control

Pin a cheap model with `FLUVIE_AI_MODEL`. Bound per-IP spend with
`FLUVIE_AI_RATE_LIMIT` (default 5), `FLUVIE_AI_RATE_WINDOW` (default `1m`), and
`FLUVIE_AI_DAILY_QUOTA` (default 50); over-limit requests get HTTP `429` with a
`Retry-After` header. A render job now also includes `code` (the printed Dart
`Video build()`) and `spec` (the authored `VideoSpec` JSON). The MCP server adds
a `spec_to_dart` tool, and `generate_video` and `edit_video` return the printed
`code`. See the [AI and MCP guide](https://docs.fluvie.dev/guides/ai-and-mcp) for
details.
