// WI-17 (§14.4): a FrameBuilder custom-paint golden. The builder reads
// ctx.progress and paints a fill bar that grows across the scene window, so the
// three probed frames show the resolved progress driving the paint — proving
// the escape hatch is frame-driven and deterministic. Subjects stay font-free
// (D20).
@Tags(['golden'])
library;

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/frame_builder.dart';

import 'helpers/golden_frame.dart';

const _track = Color(0xFF2D3436);
const _fill = Color(0xFF6C5CE7);

/// A FrameBuilder painting a horizontal bar whose fill width tracks
/// `ctx.progress` over a font-free track.
Widget _progressBar() => Center(
  child: SizedBox(
    width: 100,
    height: 24,
    child: FrameBuilder(
      (ctx) => CustomPaint(painter: _BarPainter(ctx.progress)),
    ),
  ),
);

Future<void> main() async {
  await goldenMotionFrames(
    description: 'frameBuilder: a progress bar fills across the scene window',
    fileName: 'frame_builder_progress',
    frames: const [0, 30, 59],
    subject: _progressBar,
  );
}

/// Paints a dark track with a [progress]-wide accent fill.
class _BarPainter extends CustomPainter {
  const _BarPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final track = Paint()..color = _track;
    final fill = Paint()..color = _fill;
    canvas
      ..drawRect(Offset.zero & size, track)
      ..drawRect(Rect.fromLTWH(0, 0, size.width * progress, size.height), fill);
  }

  @override
  bool shouldRepaint(_BarPainter oldDelegate) => oldDelegate.progress != progress;
}
