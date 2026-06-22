# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the versions follow [Semantic Versioning](https://semver.org/).

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
