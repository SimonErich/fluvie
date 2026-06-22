# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the versions follow [Semantic Versioning](https://semver.org/).

## [0.1.3] - 2026-06-22

Lockstep release with the rest of the workspace; no changes to this package.

## [0.1.2] - 2026-06-21

Lockstep release with the rest of the workspace; no changes to this package.

## [0.1.1] - 2026-06-21

### Added

- A landing page at `GET /` so the bare host serves a short help page (linking the
  docs, the source, and the `/v1` endpoints) instead of a `404`.

## [0.1.0] - 2026-06-20

The first public release.

### Added

- An async HTTP render API: submit a composition key, a `VideoSpec`, a prompt, or
  an edit; poll the job; download the video and poster.
- Two libraries: `package:fluvie_api/client.dart` (web-safe, `http` only) and
  `package:fluvie_api/server.dart` (the `dart:io`/`shelf` server).
- Local and S3-compatible storage, public-or-private files with signed download
  URLs, a bounded render queue, scheduled retention cleanup, and health probes.
- A `Dockerfile` and `docker-compose.yml` for one-command deployment.

[0.1.1]: https://github.com/SimonErich/fluvie/releases/tag/v0.1.1
[0.1.0]: https://github.com/SimonErich/fluvie/releases/tag/v0.1.0
