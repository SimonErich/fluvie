# mobile_purrfect

Kitten Mitten on-device studio: render a cat birthday card to MP4 on your phone.

## Run the app

Use the workspace-pinned Flutter SDK (3.44.0) and an Android or iOS device:

```sh
flutter run -d DEVICE_ID
```

## Verify Android media output

From this directory, run the real native encoder test and then independently
decode its retained artifacts. `adb`, `ffprobe`, `ffmpeg`, and Python 3 must be on
the host's path. Select an Android 9/API 28 or newer test device or a dedicated
emulator; the test writes only this app's private cache.

```sh
flutter test --no-pub --no-uninstall -d DEVICE_ID integration_test/native_media_acceptance_test.dart
python3 tool/verify_android_media.py --serial DEVICE_ID \
  --output ../../build/release-hardening/android-artifacts
```

The test generates a four-second H.264/AAC source, re-imports it as a trimmed
clip with a 0.5-to-1.5 speed ramp, volume automation and fades, and exports it at
two resolutions. Missing audio files placed at/after the output boundary prove
that inaudible tracks are rejected before materialization. Native probing and
frame extraction must return real audio metadata and expected colors. The host
verifier then checks all 240 decoded video frames, their timestamps/frame count,
and decoded PCM gain, changing pitch, and fades. It writes `verification.json`
alongside the MP4s, native probe report and Android device properties.

Android's current rate conversion changes pitch; this acceptance checks that
documented behavior. An emulator pass establishes native Android functionality,
not physical-device throughput or codec coverage. H.265 requires a separate
device capability check.

## Verify iOS media output

The iOS AVFoundation probe/frame reader is implemented, but native compilation
and acceptance have not been executed in the Linux implementation environment.
Run the following on a Mac with Xcode, an installed iPhone simulator runtime,
Flutter 3.44.0, Python 3, and FFmpeg. The repository's `example_ios_media` CI job
performs the same build and simulator checks; no remote CI run was triggered
while implementing this change.

The iOS host is generated locally because this example currently checks in its
Android host. From this directory:

```sh
flutter create --platforms=ios --org dev.fluvie --project-name mobile_purrfect --no-pub .
flutter pub get
flutter build ios --simulator --debug --no-codesign --no-pub
xcrun simctl list devices available
# Use a booted simulator UDID from the list in place of SIMULATOR_UDID.
flutter test --no-pub --no-uninstall -d SIMULATOR_UDID integration_test/native_clip_reader_test.dart
flutter test --no-pub --no-uninstall -d SIMULATOR_UDID integration_test/native_media_acceptance_test.dart
bundle_id=$(plutil -extract CFBundleIdentifier raw -o - build/ios/iphonesimulator/Runner.app/Info.plist)
python3 tool/verify_ios_media.py --device SIMULATOR_UDID --bundle-id "$bundle_id" \
  --output ../../build/release-hardening/ios-artifacts
```

The clip reader test checks every fixture frame, including a 90-degree display
rotation, 30000/1001 fps, variable presentation intervals and B-frame reorder.
It also verifies malformed iOS extraction requests fail before allocation.
The media verifier independently decodes the three retained MP4s and checks
pixel colors, frame timestamps, PCM gain/fades and iOS's explicit pitch-preserving
spectral time scaling. Simulator acceptance is a prerequisite; physical-device
throughput and HEVC codec coverage remain separate checks.
