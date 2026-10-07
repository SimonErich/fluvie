# Android audio timing

Android export mixes audio on the composition clock, then encodes AAC. AAC
priming must be removed at playback; otherwise a correctly mixed fade or sound
cue arrives late. `MediaFormat.KEY_ENCODER_DELAY` describes decoder trimming,
but the AAC encoder need not return it, and Android's MPEG4 writer does not
serialize that key into an audio edit. See the [MediaFormat contract](https://developer.android.com/reference/android/media/MediaFormat#KEY_ENCODER_DELAY)
and [Android MPEG4Writer implementation](https://android.googlesource.com/platform/frameworks/av/+/master/media/libstagefright/MPEG4Writer.cpp).

`AudioMixEncoder` measures the selected AAC codec's delay once per process and
codec name. It encodes a bounded pair of opposite impulses and decodes them with
the same platform path used for imported audio. A correlation over at most 8,192
candidate samples finds priming independently of the user's signal. Inaudible,
truncated, or out-of-range calibration fails explicitly. There is no assumed
emulator/device delay. The fixed 44.1 kHz, stereo, AAC-LC, 128 kbps configuration
is shared by calibration and export.

The real mix receives enough trailing silence to drain the codec. Sample-based
input timestamps avoid cumulative rounding error. After muxing, `Mp4AudioWindow`
adds a version-1 audio edit list with the measured media start and exact output
duration. Encoded chunks and chunk offsets stay unchanged: replacement movie
metadata is appended, and the previous movie box becomes free space. Metadata
parsing validates sizes and uses a 64 MiB bound. This runs on an owned staging
file; only the completed result is renamed to the requested output.

The calibration is less than one second of input audio and is cached for later
exports in the process. Runtime cost depends on the device and codec. Emulator
timings are diagnostic evidence, not physical-device performance promises.

## Reproduce the checks

From `examples/mobile_purrfect/android`:

```sh
./gradlew :fluvie_mobile_encoder:testDebugUnitTest --max-workers=2
```

From `examples/mobile_purrfect`, with the workspace-pinned Flutter SDK:

```sh
flutter test --no-pub --no-uninstall -d DEVICE_ID integration_test/native_media_acceptance_test.dart
python3 tool/verify_android_media.py --serial DEVICE_ID \
  --output ../../build/release-hardening/android-artifacts
```

The native unit tests cover measured delays, malformed/large-size MP4 boxes,
metadata limits, and preservation of existing media offsets. The device test
uses real capture, AAC/H.264 encoding, clip probing and frame extraction. The
host oracle decodes all 240 output frames and PCM, checking frame timestamps,
color changes, source trim/ramp timing, volume automation and fades. Android rate
conversion intentionally changes pitch; iOS uses a separate constant-pitch
expectation in the same local-artifact verifier.

A successful emulator run establishes that configuration's native behavior. It
does not certify every hardware codec, a physical-device performance target,
H.265 availability, or iOS native execution.
