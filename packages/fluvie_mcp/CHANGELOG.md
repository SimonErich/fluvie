# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the versions follow [Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-06-20

The first public release.

### Added

- An MCP server exposing five tools: `generate_video`, `edit_video`,
  `render_video`, `render_composition`, and `get_video_spec_schema`.
- Two transports: stdio (for a local assistant such as Claude Code) and
  Streamable HTTP (for a hosted endpoint), with an optional bearer token on the
  HTTP route.
- Rendering is delegated to a running Fluvie render API, so the package has no
  Flutter or FFmpeg dependency and builds into a tiny image.

[0.1.0]: https://github.com/SimonErich/fluvie/releases/tag/v0.1.0
