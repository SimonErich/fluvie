part of 'track_timeline.dart';

extension _TimelineLaneContent on _LanesPainter {
  /// The bar's filmstrip: each thumbnail drawn from its own frame up to the
  /// next one, clipped to the bar so a strip never bleeds past a trim.
  void _filmstrip(Canvas canvas, TimelineBar bar, Rect rect) {
    if (bar.thumbnails.isEmpty) return;
    canvas
      ..save()
      ..clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)));
    for (var i = 0; i < bar.thumbnails.length; i++) {
      final thumbnail = bar.thumbnails[i];
      final left = thumbnail.frame * pixelsPerFrame - scrollX;
      final right = i + 1 < bar.thumbnails.length
          ? bar.thumbnails[i + 1].frame * pixelsPerFrame - scrollX
          : rect.right;
      if (right < rect.left || left > rect.right) continue;
      paintImage(
        canvas: canvas,
        rect: Rect.fromLTRB(left, rect.top, right, rect.bottom),
        image: thumbnail.image,
        fit: BoxFit.cover,
      );
    }
    canvas.restore();
  }

  /// The lane's audio shape.
  ///
  /// One vertical stroke per bucket, mirrored about the row's middle, so a
  /// loud passage reads as a thick band and a silent one as a hairline. The
  /// envelope spans the whole timeline, because that is what a lane's audio
  /// does; a bar riding it is a window onto it, not a container for it.
  ///
  /// Drawn over the bars rather than under them. An audio lane's bar usually
  /// covers its whole envelope, and a shape hidden behind an opaque bar is a
  /// shape nobody can read.
  void _envelope(Canvas canvas, Size size, TimelineTrack track, double top, double height) {
    final envelope = track.envelope;
    if (envelope == null || envelope.buckets.isEmpty) return;
    final middle = top + height / 2;
    final reach = (height - 8) / 2;
    final paint = Paint()..color = detail.withValues(alpha: 0.4);
    final span = totalFrames * pixelsPerFrame;
    final step = span / envelope.buckets.length;
    if (step <= 0) return;
    for (var i = 0; i < envelope.buckets.length; i++) {
      final x = i * step - scrollX;
      if (x < -step || x > size.width) continue;
      final half = envelope.buckets[i].peak.clamp(0.0, 1.0) * reach;
      canvas.drawRect(
        Rect.fromLTRB(x, middle - half, x + (step < 1 ? 1 : step), middle + half),
        paint,
      );
    }
  }

  void _bar(Canvas canvas, Size size, TimelineBar bar, double top, double height) {
    final rect = Rect.fromLTRB(
      bar.start * pixelsPerFrame - scrollX,
      top + 4,
      bar.end * pixelsPerFrame - scrollX,
      top + height - 4,
    );
    if (rect.right < 0 || rect.left > size.width) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = bar.color.withValues(alpha: 0.9),
    );
    _filmstrip(canvas, bar, rect);
    final easing = bar.easing;
    if (easing != null && rect.width >= 24) {
      final inner = rect.deflate(3);
      final path = Path();
      for (var i = 0; i <= 24; i++) {
        final t = i / 24;
        final x = inner.left + t * inner.width;
        final y = inner.bottom - easing.transform(t) * inner.height;
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = detail.withValues(alpha: 0.85),
      );
    }
    final badge = bar.badge;
    if (badge != null && rect.width >= 48) {
      final painter = TextPainter(
        text: TextSpan(text: badge, style: badgeStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: rect.width - 12);
      painter
        ..paint(canvas, Offset(rect.left + 6, rect.center.dy - painter.height / 2))
        ..dispose();
    }
    if (selectedBarIds.contains(bar.id)) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.inflate(1), const Radius.circular(5)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = detail,
      );
    }
    if (bar.violation) {
      canvas
        ..drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = violationColor,
        )
        ..drawRect(
          Rect.fromLTWH(rect.left, rect.bottom + 1, rect.width, 2),
          Paint()..color = violationColor,
        );
    }
    for (final diamond in bar.diamonds) {
      _paintDiamond(
        canvas,
        Offset(diamond.frame * pixelsPerFrame - scrollX, rect.center.dy),
        selected: diamond.id == overlays.selectedDiamondId,
        fill: detail,
        selectedFill: playheadColor,
        outline: background,
      );
    }
  }
}
