import 'dart:async';

import 'ffmpeg_provider.dart';

/// Stub implementation for non-web platforms.
///
/// This file is imported on native platforms where WASM FFmpeg is not available.

Future<bool> isAvailable() async => false;

Future<FFmpegSession> startSession(FFmpegSessionConfig config) async {
  throw const FFmpegNotAvailableException(
    'WASM FFmpeg is only available on web platforms',
    installationInstructions: '''
To use FFmpeg on native platforms, use ProcessFFmpegProvider instead.

For web support, make sure you're running on a web platform and have
included the ffmpeg.wasm script in your index.html.
''',
  );
}

Future<void> dispose() async {}
