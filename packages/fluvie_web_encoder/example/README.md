# fluvie_web_encoder example

Renders a Fluvie `Video` to an MP4 entirely in the browser with
[`fluvie_web_encoder`](../). It also doubles as the package's end-to-end check: on
load it renders a one second clip and prints `FLUVIE_E2E_RESULT ok bytes=<n>` to
the browser console.

## Run it

The ffmpeg.wasm core is tens of megabytes, so it is fetched locally rather than
committed. Vendor it once, then run on Chrome:

```sh
tool/fetch_ffmpeg.sh        # needs npm; writes web/ffmpeg/
flutter run -d chrome
```

## How it is wired

- `lib/main.dart` wraps the app in a `FluvieWebStage` and calls
  `WebVideoRenderer().render(...)`. That is the whole API.
- `web/index.html` installs the page-global `FluvieFfmpeg` bridge that the
  renderer drives, loading the vendored core lazily on the first render. Ship the
  same bridge in your own app's `index.html`.

See the [on-device web rendering guide](https://docs.fluvie.dev/guides/on-device-web-rendering/)
for the full walkthrough.
