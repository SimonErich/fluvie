# A shared authoring workspace

Open the package-owned workspace for a Dart composition:

```sh
fluvie workspace lib/my_video.dart
```

Open the printed local URL. Capture an exact frame, compare it with the previous
capture, review representative frames, inspect diagnostics and export the video.
Review findings show their code, interval and remedy, with an **Inspect frame**
action tied to the reviewed source revision. The page also shows the current
Dart source. Edit that source in your normal
editor. The workspace creates no app or rendering harness in your project.

The browser displays PNGs captured by the native Flutter test engine. Its export
uses that same capture backend and the managed FFmpeg pair. Use
`--enable-impeller` when your composition needs that backend. Use
`fluvie preview lib/my_video.dart` for continuous browser or device playback.

## One worker per source revision

The first request starts a Flutter worker. Subsequent frame, inspection, review
and export requests reuse its compilation and engine. Each request mounts a new
composition and releases its resources. Source or resolved dependency changes
retire the worker before the next request. A change during capture rejects the
result as stale.

Every result records `sourceRevision`, `backend`, `workerPid`,
`startupMilliseconds`, `captureMilliseconds` and `elapsedMilliseconds`.
Startup includes staging and compilation; capture measures the engine request;
elapsed time also includes fingerprinting, encoding and verification. Compare
warm requests separately from first startup.

Worker readiness and engine requests each allow five minutes by default. Cold
Flutter compilation can take longer on a large or busy project. Set
`--startup-timeout <seconds>` and `--request-timeout <seconds>` on `workspace`
when needed; both require positive whole seconds. Custom hosts pass
`startupTimeout`/`requestTimeout` to `NativeRenderWorker.start`, or
`workerStartupTimeout`/`workerRequestTimeout` to `WorkspaceSession`.
The descriptor records these budgets. The session CLI allows fifteen minutes
for the whole HTTP request; override it with `--timeout <seconds>` when using
longer worker budgets or exports.

The revision covers local source, resolved dependency libraries and declared
resources through the existing content fingerprint. The watcher detects ordinary
filesystem metadata changes. Runtime network content, undeclared external files
and changes that preserve filesystem metadata require restarting the workspace
and reviewing their identity separately.

## Let an assistant inspect the same session

The workspace prints the path to a private `session.json` descriptor under
`build/fluvie/<name>.workspace/`. Pass it to the session command:

```sh
fluvie session build/fluvie/my_video.workspace/session.json status
fluvie session build/fluvie/my_video.workspace/session.json frame --frame 45
fluvie session build/fluvie/my_video.workspace/session.json review
fluvie session build/fluvie/my_video.workspace/session.json render --frames 60
```

These requests use the running worker. Frame results name a local PNG an
assistant can open. Review returns samples, mounted facts and repeatability
evidence. Export returns the verified artifact and receipt. `source` returns the
authored Dart. `inspect` returns mounted timeline and resource facts.

Use `--revision <sourceRevision>` when a request must refer to a previously
inspected revision. A mismatch fails before rendering. The descriptor is removed
when the workspace stops. Press Ctrl+C to stop the server and reap its worker;
the result files remain available.

## HTTP interface

The descriptor contains a loopback `endpoint` and a per-session `token`.
Requests carry `X-Fluvie-Token`. Redirects and remote descriptors are rejected by
the session command. The server accepts only its own origin and loopback host.

| Request | Result |
| --- | --- |
| `GET /status` | Source, revision, backend and worker state |
| `GET /source` | Entry source, limited to 256 KiB |
| `POST /jobs` | Serialized capture, review, inspection or export |
| `GET /artifact?path=<absolute-path>` | An existing file inside the result directory |

A job is a JSON object with `operation`: `frame`, `review`, `inspect` or
`render`. Optional fields are `frameIndex`, `frameCount`, `reviewFrames`,
`reviewDeterminism`, `aspect`, `quality`, `format` and `sourceRevision`.
Indexes must fit the authored timeline. Review accepts at most 24 sample frames.
The queue admits at most four requests and job bodies are limited to 64 KiB.
Unknown fields and invalid types fail explicitly.

The token grants access to this local source and its artifacts. It is not a
provider API key. Keep the descriptor private. This host executes your Dart
composition and provides no sandbox for untrusted code.

## Custom hosts

`runFluvieWorker` is exported from `package:fluvie/rendering.dart`. A custom host
supplies its entry factory and `RenderHostContext` callbacks. Runtime requests
use `RenderInvocation.fromJson`; rendering stays in `runFluvieRender`.
The launcher owns the private mailbox, process lifetime and source invalidation.
For a different rendering engine, retain the existing `--renderer` or `--harness`
render extension. Workspace requests use the managed engine.

For intentional quality findings, send `allowQuality` with known finding codes
and `strictQuality: true` to fail on remaining warnings. The session CLI exposes
`--allow-quality` and `--strict-quality`. Findings stay in the result, including
explicit exceptions. See [review diagnostics](reviewing-a-video.md).

## Where to next

- [Reviewing a video](reviewing-a-video.md): text, audio and repeatability checks.
- [Portable projects](portable-projects.md): restore and replay a recorded project.
- [Authoring benchmarks](authoring-benchmarks.md): measure model edits and exports.
