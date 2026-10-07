import 'package:fluvie/fluvie.dart';

/// Browser-only audio playback of the native FFmpeg preview mix.
LocalPreviewAudioController createLocalPreviewAudioController({
  required Uri endpoint,
  required String sessionToken,
}) => throw UnsupportedError('Local preview audio requires a browser.');

/// Native placeholder preserving the browser factory's public interface.
final class LocalPreviewAudioController implements PreviewAudioController {
  /// Creates the browser-only placeholder.
  LocalPreviewAudioController();
  @override
  Future<void> activate() async =>
      throw UnsupportedError('Local preview audio requires a browser.');
  @override
  Future<void> synchronize({
    required Duration position,
    required bool playing,
    required double rate,
  }) async {}

  /// Refetches the changed mix in a browser.
  Future<void> reload() async {}
  @override
  Future<void> dispose() async {}
}
