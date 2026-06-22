/// What the MCP server exposes.
enum McpMode {
  /// Documentation helper only: search and read the bundled docs and fetch the
  /// VideoSpec schema. Needs no render backend, so it works in the slim image.
  docs,

  /// The documentation tools plus the render/author tools, which need a render
  /// backend (the in-process API or a remote one via `FLUVIE_API_URL`).
  build,
}
