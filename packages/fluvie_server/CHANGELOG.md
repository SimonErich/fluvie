# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the versions follow [Semantic Versioning](https://semver.org/).

## [0.3.0] - 2026-07-16

Lockstep release with the rest of the workspace; replace this note with
the package changes, or leave it if there are none.

## [0.2.0] - 2026-07-06

### Changed

- The render path consumes `package:fluvie/rendering.dart` and the shared
  `VideoRenderer` contract; the MCP render-verb descriptions state what
  each verb produces.
- The authored and validated spec vocabulary tracks the 0.2.0 surface
  (`whenEnds`, `reveal`, `period`, `slideFadeIn`).

## [0.1.10] - 2026-06-24

Lockstep release; no changes to this package since 0.1.9.

## [0.1.9] - 2026-06-23

Lockstep maintenance release; demo (mobile layout) and CI fixes only, no library changes since 0.1.8.

## [0.1.8] - 2026-06-23

### Fixed

- CORS headers are now applied to error responses (including the auth 401)
  and preflight requests, not only successful ones. A cross-origin client
  (the Playground) previously saw a bearer-auth 401 as a misleading CORS
  error because the error response carried no `Access-Control-Allow-Origin`.

## [0.1.7] - 2026-06-23

Lockstep maintenance release; demo and deploy fixes only, no library changes since 0.1.6.

## [0.1.6] - 2026-06-23

Lockstep maintenance release; no functional changes since 0.1.5.

## [0.1.5] - 2026-06-23

### Added

- Per-client in-memory rate limiting in front of the render and validate
  routes.
- A canonical spec-to-Dart printer that produces the editable code the
  Playground shows.
- An `init` MCP tool that mirrors `fluvie init` for agents.

## [0.1.4] - 2026-06-22

The first release of `fluvie_server`. It consolidates the former `fluvie_api` and
`fluvie_mcp` packages into one self-hostable binary.

### Added

- The render API (`/v1`, the former `fluvie_api`), the MCP server (`/mcp` and
  `--stdio`, the former `fluvie_mcp`), and a new documentation helper, in one
  binary. Each capability is toggled by an environment variable
  (`FLUVIE_ENABLE_API` / `_MCP` / `_DOCS`).
- A documentation helper backed by an in-memory full-text (BM25) index over the
  bundled docs: the `list_docs`, `search_docs`, and `get_doc` MCP tools, plus an
  optional `/v1/docs` HTTP mirror.
- Two MCP modes: `docs` (the helper and the spec schema, no render backend) and
  `build` (the docs tools plus the render/author tools). Build mode renders
  in-process via `LocalRenderGateway` when the API is enabled, or against a remote
  `FLUVIE_API_URL`.
- Two libraries: `package:fluvie_server/client.dart` (web-safe, `http` only) and
  `package:fluvie_server/server.dart` (the `dart:io`/`shelf` server).

### Migrating from `fluvie_api` / `fluvie_mcp`

- Replace the `fluvie_api` / `fluvie_mcp` dependency with `fluvie_server`.
- `package:fluvie_api/client.dart` → `package:fluvie_server/client.dart`;
  `package:fluvie_api/server.dart` → `package:fluvie_server/server.dart`.
- The `/v1` routes, the `/mcp` contract, and every env var name are unchanged.
