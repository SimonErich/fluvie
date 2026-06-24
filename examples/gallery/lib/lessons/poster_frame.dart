import 'package:fluvie/fluvie.dart';

/// Resolves the poster frame of [video]: `video.poster ?? Time.zero` against
/// the video's own root scope — the frame the goldens pin and
/// the inspector opens on.
int posterFrameOf(Video video) => (video.poster ?? Time.zero).resolveFrames(
  _RootScope(fps: video.fps, durationFrames: video.totalFrames),
);

/// The root resolution scope of a [Video]: frame zero, the video's own fps
/// and total length — exactly what `Video` itself resolves times against.
final class _RootScope implements TimeScope {
  const _RootScope({required this.fps, required this.durationFrames});

  @override
  final int fps;

  @override
  final int durationFrames;

  @override
  int get startFrame => 0;

  @override
  TimeScope? get parent => null;
}
