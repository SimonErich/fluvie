# Example apps

Fluvie ships a set of small, kitten-themed example apps under `examples/`. Each
one exercises a different way to turn a Fluvie composition into a real MP4, so
together they cover every rendering path. They share one cohesive look through
the `examples/kitten_kit` package (theme, sample media, and reusable composition
builders), so each app stays tiny.

| App | What it shows | Renders with |
|---|---|---|
| `gallery` | The twelve lessons and the scrubbable inspector | CLI (desktop) and the server (web) |
| `cli_quickstart` | Install the CLI and render from the terminal | `fluvie_cli` |
| `desktop_studio` | A Linux desktop studio that renders to a file | `fluvie_cli`, in-process |
| `mobile_purrfect` | An Android app that renders on the phone | `fluvie_mobile_encoder` |
| `web_browser_studio` | A meme maker that renders in the browser | `fluvie_web_encoder` (ffmpeg.wasm) |
| `web_server_studio` | A promo studio that renders on a server | `fluvie_server` |

## Run the CLI quickstart

A tiny project with one composition and a capture harness. Render it with the
CLI and you get an MP4.

```sh
cd examples/cli_quickstart
dart run fluvie_cli:fluvie render whisker_standup --out build/whisker.mp4
```

## Run the desktop studio (Linux)

Pick a template, then render it to a file. The app shells out to the CLI.

```sh
cd examples/desktop_studio
flutter run -d linux
```

## Run the mobile app (Android)

Name your cat, optionally add a photo, and render a birthday card on the device.
Nothing leaves the phone.

```sh
cd examples/mobile_purrfect
flutter run -d android
```

## Run the in-browser meme maker

Renders fully in the browser with ffmpeg.wasm, no backend. Vendor the wasm core
once, then run.

```sh
cd examples/web_browser_studio
bash tool/fetch_ffmpeg.sh
flutter run -d chrome
```

## Run the server-render studio

Customize a promo and render it on a Fluvie render server. Point it at a running
server (see [Rendering on a server](rendering-on-a-server.md)).

```sh
cd examples/web_server_studio
flutter run -d chrome --dart-define=FLUVIE_API_URL=http://localhost:8080
```

## Run the gallery

The twelve lessons plus the inspector. Run it from the repo root so its render
button can find the CLI.

```sh
cd examples/gallery
flutter run
```

## How they are tested

Each app is verified end to end in CI: the build compiles, unit tests cover the
view-models and services, and a real render produces an MP4 that is probed for a
valid video stream. The web apps print a `FLUVIE_E2E_RESULT` marker the headless
harness reads; the desktop and mobile apps assert the written file. See
[Testing](../contributing/testing.md).

## Where to next

- [Your first video](../getting-started/your-first-video.md): write a composition from scratch.
- [On-device mobile rendering](on-device-mobile-rendering.md) and [in the browser](on-device-web-rendering.md).
- [Rendering on a server](rendering-on-a-server.md): stand up the render API the server studio calls.
