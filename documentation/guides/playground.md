# The Playground

The Playground lets anyone write a Fluvie `Video build()` in the browser, check
it, and render it to a real video without installing anything. It is the "Code"
tab on [the live demo](https://demo.fluvie.dev), and a reusable widget you can
drop into your own app.

It is two server calls: validate the code, then render it. The code never runs in
the browser, because a browser cannot compile Dart. It runs server-side, in a
sandbox.

## Try it

Open [demo.fluvie.dev](https://demo.fluvie.dev), edit the snippet in the Code tab,
and press **Render**. The editor validates your code first (a "Validating ..."
state), shows any errors inline, and renders only when it is clean. The result
plays on the left, replacing the default video.

## Generate with AI

You do not have to start from a blank editor. Type a prompt into the AI Assistant,
such as "a 6 second vertical title card on a dark gradient," and press generate.
The browser sends the prompt to the server. The server authors the video with its
configured model and returns editable Flutter-style Dart, which lands in the
editor. From there it is normal code: edit it and press Render.

You can keep refining with the AI too. A follow-up prompt edits the current
video, changing only what you ask, so "make it red" recolours the title without
disturbing the rest.

The model runs server-side, so the browser never holds an API key. On the hosted
demo, generation uses the operator's key behind a free daily quota, so you can try
it without signing up. The same prompt path is available over MCP and the CLI; see
[AI and MCP](ai-and-mcp.md) for those and for the deploy and cost settings.

A polling client sees the generated code early. The render job carries a `code`
field that the server fills as soon as it has authored the snippet, before the
video finishes. A client polling `GET /v1/renders/{id}` reads `code` while
`status` is still `running`, so it can show the editable Dart while the render runs.

## The two endpoints

The Playground talks to a [`fluvie_server`](rendering-on-a-server.md). Both calls
take a bearer token when the server sets one.

Validate runs static analysis only and never executes the code:

```sh
curl -X POST https://api.fluvie.dev/v1/validate \
  -H 'authorization: Bearer <token>' \
  -H 'content-type: application/json' \
  --data @snippet.json
```

where `snippet.json` holds the code:

```json
{ "code": "import 'package:fluvie/fluvie.dart';\nVideo build() => Video(scenes: const []);" }
```

It returns the Dart analyzer and `fluvie_lints` diagnostics, each located for an
editor to mark:

```json
{
  "ok": false,
  "diagnostics": [
    { "severity": "error", "message": "Undefined name 'Vid'.", "line": 2, "column": 18, "length": 3, "code": "undefined_identifier" }
  ]
}
```

`ok` is `true` when no diagnostic is an error; warnings do not block a render.

Render validates first, then runs the code in a sandbox:

```sh
curl -X POST https://api.fluvie.dev/v1/renders \
  -H 'authorization: Bearer <token>' \
  -H 'content-type: application/json' \
  --data @snippet.json
```

A clean snippet returns `202` with a job to poll, exactly like a key or spec
render (see [rendering on a server](rendering-on-a-server.md)). Code that fails
validation, or imports a library outside the allowlist, returns `422` with the
same diagnostics and is never run.

## What you can write

The contract is one top-level function:

- `Video build()`: zero arguments, synchronous, returns a `Video`.
- Imports are limited to `package:fluvie`, `package:flutter` (the UI framework),
  `dart:math`, and `dart:ui`. `dart:io`, `dart:ffi`, `dart:isolate`, networking,
  and any other package are rejected before the code is ever compiled.

## Safety

Rendering submitted code is running untrusted code, so Fluvie gates it. The import
allowlist and the static analyzer run first and never execute anything. Only a
clean snippet is rendered, in a fresh per-render directory, with the AI provider
keys stripped from its environment and a wall-clock ceiling on the capture.

Directory isolation is not a security boundary on its own. Before opening the
Playground to anonymous traffic, run each render in a throwaway container (for
example gVisor).

## Where to next

- [Rendering on a server](rendering-on-a-server.md) sets up the `fluvie_server`
  the Playground renders through.
- [Authoring with specs](authoring-with-specs.md) is the other way to render
  without hand-written Dart: a JSON `VideoSpec` a model can emit.
