import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/rendering/capture/raw_frame.dart';
import 'package:fluvie/src/rendering/encoding/frame_extraction_service.dart';

/// Canned [FrameExtractionService] for tests: serves fixed frames per
/// `source -> frameIndex` and throws a typed error for anything not canned.
///
/// This is the Seams Ledger fake for `FrameExtractionService` until the
/// ffmpeg-backed implementation lands in Phase 8.3.
final class FakeFrameExtractionService implements FrameExtractionService {
  /// Creates a service serving exactly [canned] (source → frame index → frame).
  FakeFrameExtractionService(Map<Uri, Map<int, RawFrame>> canned)
    : _canned = {
        for (final entry in canned.entries) entry.key: Map.of(entry.value),
      };

  final Map<Uri, Map<int, RawFrame>> _canned;

  @override
  Future<RawFrame> extractFrame(
    Uri source,
    int frameIndex, {
    required int width,
    required int height,
  }) async {
    final frame = _canned[source]?[frameIndex];
    if (frame == null) {
      throw FluvieRenderException(
        'FakeFrameExtractionService has no canned frame $frameIndex for "$source".',
      );
    }
    return frame;
  }
}
