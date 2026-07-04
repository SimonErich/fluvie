# fluvie_mobile_encoder example

`main.dart` is the smallest on-device render: one button, one `Video`, one
`OnDeviceVideoRenderer().render(...)` call that returns the encoded MP4 file.
Run it on a real Android or iOS device (the encode uses the platform's native
encoder, so a simulator without hardware encoding may fall back or fail).

For a complete app on this path — media picking, progress, audio, sharing —
see
[`examples/mobile_purrfect`](https://github.com/SimonErich/fluvie/tree/main/examples/mobile_purrfect);
the guide is
[On-device mobile rendering](https://docs.fluvie.dev/guides/on-device-mobile-rendering/).
