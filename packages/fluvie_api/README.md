# fluvie_api

An HTTP API that renders [Fluvie](https://pub.dev/packages/fluvie) videos to
files, plus a web-safe client to drive it. Submit a composition key, a
`VideoSpec`, or a natural-language prompt; the server renders asynchronously,
stores the file locally or on S3-compatible storage, and returns a download URL.

[![pub package](https://img.shields.io/pub/v/fluvie_api.svg)](https://pub.dev/packages/fluvie_api)
[![license: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)

The package ships two libraries:

- `package:fluvie_api/client.dart`, a web-safe HTTP client (`http` only),
  usable from any Flutter app (web, mobile, desktop).
- `package:fluvie_api/server.dart`, the `dart:io`/`shelf` server. Not web-safe.

## Run the server

```sh
cp deploy/env/api.env.example deploy/env/api.env   # set API_TOKEN and CLEANUP_TOKEN
docker compose -f deploy/docker-compose.yml up --build
```

Then:

```sh
curl -s -X POST http://localhost:8080/v1/renders \
  -H "Authorization: Bearer $API_TOKEN" -H "content-type: application/json" \
  -d '{"key":"demo"}'
```

See the [Rendering on a server](https://docs.fluvie.dev/guides/rendering-on-a-server/)
guide for the full API, local-vs-S3 storage, public-vs-private files, scheduled
cleanup, and the environment variables.

## Use the client

```dart
import 'package:fluvie_api/client.dart';

final client = ApiRenderClient(
  baseUrl: Uri.parse('https://render.example.com'),
  apiToken: 'your-token',
);

final job = await client.renderAndWait(
  ApiRenderRequest.key('demo'),
  onUpdate: (view) => print('${view.status} ${view.progress}'),
);
print('Download: ${job.video?.downloadUrl}');
client.close();
```

`ApiRenderRequest` also has `.spec(...)`, `.prompt(...)`, and `.edit(...)`
factories. The client is an `interface class`, so tests can mock it.

## How it renders

Rendering is the same two-process pipeline as the
[fluvie_cli](https://pub.dev/packages/fluvie_cli): capture frames with
`flutter test` (headless software rendering, no display server), then encode with
ffmpeg. The server drives a configurable `RENDER_PROJECT` (the example app by
default) and runs jobs through a bounded queue.

## Status

On-device rendering on web and mobile is not supported yet, so a hosted web app
renders through this server. See the guide for details.
