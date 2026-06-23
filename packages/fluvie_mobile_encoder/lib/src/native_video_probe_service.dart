import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_mobile_encoder/src/fluvie_mobile_encoder_exception.dart';

/// A [VideoProbeService] backed by the platform: reads a clip's dimensions,
/// frame count, and duration through the device (`MediaMetadataRetriever` on
/// Android, `AVAsset` on iOS) over the mobile encoder channel — no ffmpeg/
/// ffprobe, so it works on a real device where no binary is present.
///
/// The reported dimensions are capped to [maxLongEdge] so a clip is decoded at
/// most at the render's own resolution (it is composited into the render frame
/// anyway) — decoding a 4K source frame-by-frame would waste memory and time
/// for no visible gain. The clip resolver streams frames from disk, so this is a
/// quality/throughput bound, not the old hard memory limit; the default matches
/// a 1080×1920 reel.
final class NativeVideoProbeService implements VideoProbeService {
  /// Creates the service over an optional [MethodChannel] (defaults to the
  /// package channel; tests pass a mock-backed channel).
  const NativeVideoProbeService([
    this._channel = _defaultChannel,
    this.maxLongEdge = 1920,
  ]);

  static const MethodChannel _defaultChannel = MethodChannel(
    'dev.fluvie/mobile_encoder',
  );

  final MethodChannel _channel;

  /// The longest side a decoded clip frame is kept at (memory bound).
  final int maxLongEdge;

  @override
  Future<VideoProbeResult> probe(String filePath) async {
    final Map<String, Object?>? facts;
    try {
      facts = await _channel.invokeMapMethod<String, Object?>('probeVideo', {
        'path': filePath,
      });
    } on PlatformException catch (error) {
      throw FluvieMobileEncoderException(
        error.message ?? 'The platform failed to probe "$filePath".',
        code: error.code,
      );
    }
    if (facts == null) {
      throw const FluvieMobileEncoderException(
        'The platform returned no probe facts.',
        code: 'probe_failed',
      );
    }
    final durationMs = (facts['durationMs'] as int?) ?? 0;
    final (width, height) = _capped(
      (facts['width'] as int?) ?? 0,
      (facts['height'] as int?) ?? 0,
    );
    return VideoProbeResult(
      codec: (facts['codec'] as String?) ?? 'h264',
      width: width,
      height: height,
      nbFrames: (facts['frameCount'] as int?) ?? 0,
      durationSeconds: durationMs / 1000.0,
    );
  }

  /// Scales [width]x[height] down to fit [maxLongEdge] (keeping aspect) and
  /// rounds each side to an even number the encoder accepts.
  (int, int) _capped(int width, int height) {
    if (width <= 0 || height <= 0) return (width, height);
    final longEdge = math.max(width, height);
    final scale = longEdge > maxLongEdge ? maxLongEdge / longEdge : 1.0;
    int even(int value) {
      final scaled = (value * scale).round();
      return scaled.isOdd ? scaled - 1 : scaled;
    }

    return (math.max(2, even(width)), math.max(2, even(height)));
  }
}
