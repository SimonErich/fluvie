# fluvie_render_client

Use a configured Fluvie render service from Dart or Flutter on web, desktop and
mobile. This package carries HTTP requests, job views and validation diagnostics;
it does not include the server, Flutter capture engine or native FFmpeg tools.

```sh
dart pub add fluvie_render_client
```

Import `package:fluvie_render_client/fluvie_render_client.dart`. Create an
`ApiRenderClient` with your service's `baseUrl`, optional `apiToken` and an
injectable `http.Client`. Close it when its owning application scope ends.

- `ApiRenderRequest` selects an authored Dart, spec, registered key, prompt or
  spec edit request and optional export settings.
- `createRender` submits a job; `getJob` reads its status. `renderAndWait` polls
  until completion, reports updates and bounds waiting by a timeout.
- `validate` returns located static diagnostics before rendering.
- `uploadMedia` sends exact binary inputs and returns a signed asset URL. Project
  contributions require `projectId` and `contributionToken` together.
- `RenderJobView` contains progress, authored source when available, and signed
  video/poster links. `ApiClientException` retains HTTP status and server errors.

Prompt and spec-edit requests need the service's configured authoring provider.
Rendering code executes on the server under its import and resource policy.
Avoid embedding a privileged service token in a publicly distributed client;
select the authentication boundary appropriate to your application.

See the [compiled client example](https://github.com/SimonErich/fluvie/blob/main/packages/fluvie_render_client/example/render_source.dart),
[server guide](https://docs.fluvie.dev/guides/rendering-on-a-server/), and
[source-derived protocol reference](https://docs.fluvie.dev/reference/server-protocol/).
`package:fluvie_server/client.dart` continues to export this API for compatibility.
