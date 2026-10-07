import 'dart:typed_data';
import 'package:fluvie/fluvie.dart' show AudioSource;
import 'package:fluvie/rendering.dart' show MediaResolver, NetworkAllowlist, PcmAudio;

/// Platform audio output and source decoding behind a deterministic mixer.
abstract interface class AudioPreviewPlatform {
  /// Resolves and downmixes a source to bounded mono PCM for audition/analysis.
  Future<PcmAudio> decode(
    AudioSource source, {
    Uint8List? bytes,
    MediaResolver? resolver,
    NetworkAllowlist? allowlist,
  });

  /// Opens the browser audio device during the user's playback gesture.
  void unlock();

  /// Replaces the audible chunk. Completion means output has ended; device failures complete with an error.
  Future<void> play(Uint8List wav, {double offsetSeconds = 0});

  /// Cancels any pending/current output.
  Future<void> stop();

  /// Releases the device, processes and temporary files.
  Future<void> dispose();
}
