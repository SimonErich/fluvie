# fluvie_cli example

Install the CLI, then render a composition to a video file:

```sh
dart pub global activate fluvie_cli
fluvie render 01_hello_video --out hello.mp4
```

List the compositions you can render:

```sh
fluvie list
```

Render at another aspect ratio, or to a different format:

```sh
fluvie render 01_hello_video --aspect reels --out hello_vertical.mp4
fluvie render 01_hello_video --format gif --fps 15 --out hello.gif
```

You need FFmpeg on your PATH. Run `fluvie render --help` for every option. See
the [exporting guide](https://github.com/SimonErich/fluvie/tree/main/documentation/guides/exporting-your-video.md).
