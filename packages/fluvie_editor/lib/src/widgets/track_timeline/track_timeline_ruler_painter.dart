part of 'track_timeline.dart';

/// The seconds ruler: labeled major ticks at a "nice" seconds step, minor
/// ticks between them, the markers, and the playhead handle.
final class _RulerPainter extends CustomPainter {
  const _RulerPainter({
    required this.scrollX,
    required this.pixelsPerFrame,
    required this.fps,
    required this.totalFrames,
    required this.playhead,
    required this.range,
    required this.markers,
    required this.selectedMarkerId,
    required this.background,
    required this.tick,
    required this.playheadColor,
    required this.markerColor,
    required this.labelStyle,
  });

  final double scrollX;
  final double pixelsPerFrame;
  final double fps;
  final double totalFrames;
  final double playhead;
  final ({double start, double end})? range;
  final List<TimelineMarker> markers;
  final String? selectedMarkerId;
  final Color background;
  final Color tick;
  final Color playheadColor;
  final Color markerColor;
  final TextStyle labelStyle;

  /// The label step in seconds: the smallest "nice" step keeping labels at
  /// least ~64 pixels apart.
  double _stepSeconds() {
    const steps = [0.1, 0.2, 0.5, 1.0, 2.0, 5.0, 10.0, 30.0, 60.0, 120.0];
    for (final step in steps) {
      if (step * fps * pixelsPerFrame >= 64) return step;
    }
    return 300;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final paint = Paint()
      ..color = tick.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    final step = _stepSeconds() * fps * pixelsPerFrame;
    final minor = step / 5;
    final drawMinor = minor >= 8;
    final endX = totalFrames * pixelsPerFrame - scrollX;
    var x = -(scrollX % minor);
    for (; x <= math.min(size.width, endX); x += minor) {
      if (x < 0) continue;
      final position = x + scrollX;
      final major = (position / step - (position / step).roundToDouble()).abs() < 1e-6;
      if (!major && !drawMinor) continue;
      final length = major ? 7.0 : 4.0;
      canvas.drawLine(Offset(x, size.height - length), Offset(x, size.height), paint);
      if (major) _label(canvas, x, position / pixelsPerFrame);
    }
    _range(canvas, size);
    _markers(canvas, size);
    _playhead(canvas, size);
  }

  void _range(Canvas canvas, Size size) {
    final range = this.range;
    if (range == null) return;
    final left = range.start * pixelsPerFrame - scrollX;
    final right = range.end * pixelsPerFrame - scrollX;
    if (right < 0 || left > size.width) return;
    canvas.drawRect(
      Rect.fromLTRB(math.max(0, left), 0, math.min(size.width, right), size.height),
      Paint()..color = playheadColor.withValues(alpha: 0.18),
    );
    final edge = Paint()
      ..color = playheadColor.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    canvas
      ..drawLine(Offset(left, 0), Offset(left, size.height), edge)
      ..drawLine(Offset(right, 0), Offset(right, size.height), edge);
  }

  /// A major tick's label: the timecode at this frame, and the seconds it
  /// stands for underneath.
  ///
  /// Both, because they answer different questions. An author laying out a
  /// forty-second video thinks in seconds; one matching a cut to a reference
  /// reads the timecode, and a timecode without its frame count is not a
  /// timecode at all.
  void _label(Canvas canvas, double x, double frames) {
    final seconds = frames / fps;
    final rounded = (seconds * 10).roundToDouble() / 10;
    final text = rounded == rounded.roundToDouble() ? '${rounded.round()}s' : '${rounded}s';
    final code = formatTimecode(frames.round(), fps.round());
    TextPainter(
        text: TextSpan(
          text: code,
          style: labelStyle,
          children: [TextSpan(text: '  $text', style: labelStyle.copyWith(fontSize: 8))],
        ),
        textDirection: TextDirection.ltr,
      )
      ..layout()
      ..paint(canvas, Offset(x + 3, 3))
      ..dispose();
  }

  void _markers(Canvas canvas, Size size) {
    for (final marker in markers) {
      final x = marker.frame * pixelsPerFrame - scrollX;
      if (x < -8 || x > size.width + 8) continue;
      final selected = marker.id == selectedMarkerId;
      canvas.drawRect(
        Rect.fromLTWH(x - (selected ? 1 : 0.5), 0, selected ? 2 : 1, size.height),
        Paint()..color = markerColor,
      );
      final label = marker.label;
      if (label == null) continue;
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: labelStyle.copyWith(color: markerColor),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      painter
        ..paint(canvas, Offset(x + 3, size.height - painter.height - 2))
        ..dispose();
    }
  }

  void _playhead(Canvas canvas, Size size) {
    final x = playhead * pixelsPerFrame - scrollX;
    if (x < -6 || x > size.width + 6) return;
    final paint = Paint()..color = playheadColor;
    canvas
      ..drawRect(Rect.fromLTWH(x - 0.5, 0, 1, size.height), paint)
      ..drawPath(
        Path()
          ..moveTo(x - 5, 0)
          ..lineTo(x + 5, 0)
          ..lineTo(x, 7)
          ..close(),
        paint,
      );
  }

  @override
  bool shouldRepaint(_RulerPainter oldDelegate) =>
      oldDelegate.scrollX != scrollX ||
      oldDelegate.pixelsPerFrame != pixelsPerFrame ||
      oldDelegate.fps != fps ||
      oldDelegate.totalFrames != totalFrames ||
      oldDelegate.playhead != playhead ||
      oldDelegate.range != range ||
      !listEquals(oldDelegate.markers, markers) ||
      oldDelegate.selectedMarkerId != selectedMarkerId ||
      oldDelegate.background != background ||
      oldDelegate.tick != tick ||
      oldDelegate.playheadColor != playheadColor ||
      oldDelegate.markerColor != markerColor ||
      oldDelegate.labelStyle != labelStyle;
}
