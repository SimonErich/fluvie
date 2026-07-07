import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie_mobile_encoder/src/fluvie_mobile_encoder_exception.dart';
import 'package:fluvie_mobile_encoder/src/mobile_channel.dart';

/// A [FrameExtractionService] backed by the platform decoder: decodes the
/// requested source frames to RGBA on the device (`MediaMetadataRetriever` on
/// Android) over the mobile encoder channel, with no ffmpeg.
///
/// On-device frame extraction is Android-only today; iOS implements only
/// encoding, so `extractFrames` there throws a [FluvieMobileEncoderException]
/// with code `unimplemented`.
///
/// The whole batch is decoded in one platform call and returned as a single
/// row-major RGBA buffer (the requested frames concatenated in order), which
/// this slices back into one [RawFrame] per source index.
final class NativeFrameExtractionService implements FrameExtractionService {
  /// Creates the service over an optional [MethodChannel] (defaults to the
  /// package channel; tests pass a mock-backed channel).
  const NativeFrameExtractionService([this._channel = _defaultChannel]);

  static const MethodChannel _defaultChannel = MethodChannel(mobileEncoderChannelName);

  final MethodChannel _channel;

  @override
  Future<RawFrame> extractFrame(
    Uri source,
    int frameIndex, {
    required int width,
    required int height,
  }) async {
    final frames = await extractFrames(
      source,
      [frameIndex],
      width: width,
      height: height,
    );
    final frame = frames[frameIndex];
    if (frame == null) {
      throw FluvieMobileEncoderException(
        'The platform returned no frame $frameIndex for "$source".',
        code: 'extract_failed',
      );
    }
    return frame;
  }

  /// The most frames decoded per platform call. A whole multi-second batch in
  /// one call would allocate a single multi-hundred-MB buffer and exhaust the
  /// heap, so the work is chunked.
  static const int _batch = 8;

  @override
  Future<Map<int, RawFrame>> extractFrames(
    Uri source,
    Iterable<int> frameIndices, {
    required int width,
    required int height,
  }) async {
    final indices = frameIndices.toList();
    if (indices.isEmpty) return const {};
    final path = source.toFilePath();
    final frameBytes = width * height * 4;
    final frames = <int, RawFrame>{};
    for (var offset = 0; offset < indices.length; offset += _batch) {
      final chunk = indices.sublist(
        offset,
        math.min(offset + _batch, indices.length),
      );
      final Uint8List? bytes;
      try {
        bytes = await _channel.invokeMethod<Uint8List>('extractFrames', {
          'path': path,
          'indices': chunk,
          'width': width,
          'height': height,
        });
      } on MissingPluginException {
        throw const FluvieMobileEncoderException(
          'On-device frame extraction is not available on this platform (Android only).',
          code: 'unimplemented',
        );
      } on PlatformException catch (error) {
        throw FluvieMobileEncoderException(
          error.message ?? 'The platform failed to extract frames from "$source".',
          code: error.code,
        );
      }
      if (bytes == null || bytes.length != chunk.length * frameBytes) {
        throw FluvieMobileEncoderException(
          'The platform returned ${bytes?.length ?? 0} bytes for '
          '${chunk.length} frame(s) of "$source"; expected '
          '${chunk.length * frameBytes} (${width}x$height RGBA).',
          code: 'extract_failed',
        );
      }
      for (var i = 0; i < chunk.length; i++) {
        final start = i * frameBytes;
        frames[chunk[i]] = RawFrame(
          frameIndex: chunk[i],
          width: width,
          height: height,
          rgba: Uint8List.fromList(
            Uint8List.sublistView(bytes, start, start + frameBytes),
          ),
        );
      }
    }
    return frames;
  }
}
