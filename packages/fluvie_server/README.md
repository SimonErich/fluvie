# fluvie_server

[![pub package](https://img.shields.io/pub/v/fluvie_server.svg)](https://pub.dev/packages/fluvie_server)
[![license: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)

One self-hostable server for the full AI power of [Fluvie](https://fluvie.dev): the
render API, AI authoring, the MCP server, and a documentation helper, all in one
binary. Enable the parts you want with environment variables; install one image,
not three services.

## Libraries

- `package:fluvie_server/client.dart` — the web-safe render client (`http` only),
  for a Flutter app on web, mobile, or desktop. New clients can depend directly on
  `fluvie_render_client` to avoid pulling in the server runtime's dependencies.
- `package:fluvie_server/server.dart` — the `dart:io`/`shelf` server.

## Run it

```sh
dart run packages/fluvie_server/bin/fluvie_server.dart
```

The render API listens on `HOST:PORT` (default `0.0.0.0:8080`). See the
[server guide](https://docs.fluvie.dev/guides/rendering-on-a-server) and the
[AI and MCP guide](https://docs.fluvie.dev/guides/ai-and-mcp) for configuration,
the MCP modes, and Docker images.

## Embed the render service

`buildServerDependencies` accepts a host-owned `JobStore`, `RenderRunner` and
`mediaOrigin`. The queue and retention use the supplied store; durable hosts can
persist jobs with `encodeRenderJob`/`decodeRenderJob` instead of copying the
library's codec. Omitted options preserve the standalone file-backed behavior.
The host remains responsible for account authorization, atomic queue admission
and recovery of interrupted jobs.

Set `proxyS3Downloads: true` to stream S3 exports through the API after its
existing signed-link authorization. This supports same-origin browser clients
without bucket CORS and buckets reachable only by the server. The default is
direct presigned/CDN redirects. Proxy mode uses host bandwidth for downloads.
`S3FileStore(proxyDownloads: true)` exposes the same option when wiring storage
directly. `ApiRenderClient.waitForJob` polls jobs accepted by a host's own recipe
endpoint without creating another job.

The [server protocol reference](https://docs.fluvie.dev/reference/server-protocol/)
publishes HTTP and MCP examples exported from the actual serializers, parser and
tool registry. Backend support is listed in the shared
[capability registry](https://docs.fluvie.dev/reference/render-capabilities/).

## AI cost control

Pin a cheap model with `FLUVIE_AI_MODEL`. Bound per-IP spend with
`FLUVIE_AI_RATE_LIMIT` (default 5), `FLUVIE_AI_RATE_WINDOW` (default `1m`), and
`FLUVIE_AI_DAILY_QUOTA` (default 50); over-limit requests get HTTP `429` with a
`Retry-After` header. A render job now also includes `code` (the printed Dart
`Video build()`) and `spec` (the authored `VideoSpec` JSON). The MCP server adds
a `spec_to_dart` tool, and `generate_video` and `edit_video` return the printed
`code`. See the [AI and MCP guide](https://docs.fluvie.dev/guides/ai-and-mcp) for
details.

## Offline documentation

Docs mode ships the canonical documentation with the binary. A local assistant
can start with `get_authoring_context`, then use `search_docs` and `get_doc`
without a checkout or website access. `FLUVIE_DOCS_DIR` optionally overrides the
bundle with a local Markdown directory; missing or empty overrides fail clearly
at startup. The same versioned corpus is available through `fluvie docs --context`.
