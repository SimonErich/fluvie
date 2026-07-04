# fluvie_server example

`main.dart` submits a `VideoSpec` to a running render server with the web-safe
client (`package:fluvie_server/client.dart`) and polls the job to completion.

Start a server locally:

```sh
docker run --rm -p 8080:8080 -e API_TOKEN=dev -e CLEANUP_TOKEN=dev \
  ghcr.io/simonerich/fluvie-server:latest
```

Run the example against it:

```sh
FLUVIE_API_TOKEN=dev dart run example/main.dart http://localhost:8080
```

For a complete Flutter app on this path, see
[`examples/web_server_studio`](https://github.com/SimonErich/fluvie/tree/main/examples/web_server_studio);
for self-hosting, see
[Rendering on a server](https://docs.fluvie.dev/guides/rendering-on-a-server/).
