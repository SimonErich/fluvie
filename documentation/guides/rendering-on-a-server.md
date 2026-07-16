# Rendering on a server

Run Fluvie behind an HTTP API. You POST a video, the server renders it, and you
get back a download URL. Use it as a render backend for a web app, an online
editor, or a batch pipeline.

## Quick start

```sh
cp deploy/env/server.env.example deploy/env/server.env   # set API_TOKEN and CLEANUP_TOKEN
docker compose -f deploy/docker-compose.yml up --build
```

Submit a render and poll until it is done:

```sh
# Create a render of the bundled "demo" composition.
curl -s -X POST http://localhost:8080/v1/renders \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "content-type: application/json" \
  -d '{"key":"demo"}'
# => {"id":"rnd_...","status":"queued","expiresAt":"..."}

# Poll the job.
curl -s http://localhost:8080/v1/renders/rnd_... \
  -H "Authorization: Bearer $API_TOKEN"
# => {"id":"rnd_...","status":"succeeded","code":"Video build() { ... }","spec":{"fluvieSpec":1,"scenes":[...]},"video":{"downloadUrl":"http://localhost:8080/v1/files/rnd_.../video?token=..."}}

# Download the file.
curl -L -o demo.mp4 "<the downloadUrl from above>"
```

For AI `prompt` and `edit` renders, `code` (the printed Dart `Video build()`) and
`spec` (the authored `VideoSpec` JSON) appear early, while `status` is still
`running`, so an editor can show the authored source before the file is ready.

The package is [`fluvie_server`](https://pub.dev/packages/fluvie_server): one binary
that also hosts the [MCP server](ai-and-mcp.md) at `/mcp` and a documentation helper
at `/v1/docs`, each toggled by an environment variable. The server is
`dart compile exe`; the image carries the Flutter SDK and ffmpeg because rendering
captures frames with `flutter test` then encodes with ffmpeg. No display server is
needed.

## What you can render

A request body has exactly one input:

- `{"key":"demo"}` renders a composition registered in the render project.
- `{"spec":{...}}` renders a `VideoSpec` JSON document (see
  [authoring-with-specs](authoring-with-specs.md)). This is what an editor sends.
- `{"prompt":"a 10s coffee promo"}` authors a spec with an LLM, then renders it.
- `{"edit":{"base":{...},"change":"make the title pop"}}` refines a spec, then
  renders it.
- `{"code":"Video build() { ... }"}` renders a Dart `Video build()` snippet (the
  [playground](playground.md) path), statically checked before it runs.

Add `options`, `visibility`, and `ttl`:

```json
{
  "spec": { "fluvieSpec": 1, "scenes": [ /* ... */ ] },
  "options": { "format": "mp4", "aspect": "reels", "quality": "high", "poster": "1.5s" },
  "visibility": "private",
  "ttl": "48h"
}
```

A `prompt` or `edit` request needs an AI key in the environment
(`ANTHROPIC_API_KEY`, `GEMINI_API_KEY`, or `MISTRAL_API_KEY`); without one the
server answers `503`.

## The API

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| POST | `/v1/renders` | API token | Create a render job (`202`). |
| GET | `/v1/renders/{id}` | API token | Job status, with `progress`, `code`, `spec`, and download links. |
| GET | `/v1/files/{id}/{kind}` | public: none, private: token | Download `video` or `poster`. |
| POST | `/v1/maintenance/cleanup` | Cleanup token | Delete expired files. |
| GET | `/v1/schema/video-spec` | none | The `VideoSpec` JSON schema, for an editor. |
| GET | `/v1/healthz`, `/v1/readyz` | none | Liveness and readiness. |

Status codes: `202` accepted, `400` invalid body, `401` bad token, `404`
unknown, `410` expired, `413` body too large, `429` rate limit exceeded (with a
`Retry-After` header), `503` AI not configured.

## Local files or S3

The default backend writes files to a local directory (`LOCAL_STORAGE_DIR`, a
Docker volume). Switch to any S3-compatible bucket (AWS, MinIO, DigitalOcean
Spaces, Backblaze B2, Cloudflare R2) by setting `STORAGE_BACKEND=s3` and the
`S3_*` variables. Test the S3 path locally with the bundled MinIO:

```sh
docker compose --profile s3 up --build
```

## Public or private

`visibility` defaults to private (set `PUBLIC_BY_DEFAULT=true` to flip it). A
private download URL carries a signed token bound to that one file and expiry; a
public URL has none. Either way the client fetches the same
`/v1/files/{id}/{kind}` endpoint: local files stream, S3 files redirect to a
presigned (private) or public URL.

## Cleaning up expired files

Every render gets an expiry of `FILE_TTL` from creation. Two things remove
expired files:

- The built-in timer, every `CLEANUP_INTERVAL` (set it to `0` to disable).
- The `POST /v1/maintenance/cleanup` endpoint, for an external cron. It uses the
  separate `CLEANUP_TOKEN`, so a cron box never holds render rights.

```sh
curl -s -X POST http://localhost:8080/v1/maintenance/cleanup \
  -H "Authorization: Bearer $CLEANUP_TOKEN" -d '{"dryRun":true}'
# => {"scanned":12,"deletedFiles":4,"deletedJobs":2,"freedBytes":...,"dryRun":true}
```

## Rendering your own videos

To render your own compositions, point `RENDER_PROJECT` at a Fluvie project: a
directory whose `pubspec.yaml` depends on `fluvie`. That is the whole
requirement. The server generates the capture harness it needs per render, so the
project holds no harness file and no registry.

With no `RENDER_PROJECT` the server discovers a project by walking up from its
working directory, the same way the CLI does.

Spec, prompt, and code renders work against any Fluvie project. A `key` render is
the exception: it needs a project that still keeps a registry-based harness, with
that key registered in it.

Specs that reference remote `Image`/`Clip` URLs need a render project whose media
client is allowed to fetch them. The bundled example uses an offline client for
deterministic tests, so it resolves only bundled assets.

## Running the example locally or hosted

The example app renders either way:

- Desktop, no server: `flutter run -d linux` (or `macos`/`windows`). It spawns
  the Fluvie CLI, so you need a Dart SDK and ffmpeg. This is the clone-and-run
  path.
- Web or hosted, via the API: build with
  `--dart-define=FLUVIE_API_URL=https://your-server` (and
  `--dart-define=FLUVIE_API_TOKEN=...`). The app calls `fluvie_server` and shows the
  download URL.

On-device rendering on mobile is supported by
[fluvie_mobile_encoder](on-device-mobile-rendering.md): it drives Fluvie's capture
loop in the running app and encodes with the platform's native hardware encoder,
so nothing leaves the device. On the web,
[fluvie_web_encoder](on-device-web-rendering.md) does the same through ffmpeg.wasm:
it captures and encodes the video on the page, so nothing leaves the browser.

## Where to next

- [Authoring with specs](authoring-with-specs.md): the `VideoSpec` JSON the
  `spec`, `prompt`, and `edit` endpoints produce and consume.
- [Exporting your video](exporting-your-video.md): the local command-line
  renderer the server wraps, and every export format.
