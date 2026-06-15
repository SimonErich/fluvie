// WI-17: FrameBuilder is the escape hatch (API_SPEC §20). It reads the frame
// clock like Counter and hands a live FrameContext to the builder, rebuilding
// when the frame changes. A custom-paint subject painted from ctx.progress
// renders, and ctx.audio reads a tagged track from a known band table.
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/frame_builder.dart';
import 'package:fluvie/src/animation/runtime/frame_context.dart';
import 'package:fluvie/src/animation/runtime/reactive_scope.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/audio/band_table.dart';
import 'package:fluvie/src/core/audio_band.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';

const _scope = TimeScopeData(fps: 30, startFrame: 0, durationFrames: 60);

/// Mounts [child] under a frame clock at [frame], optionally under a
/// [ReactiveScope] carrying [table]/[tracks].
Widget _host(
  Widget child, {
  required int frame,
  BandTable? table,
  Map<Anchor, BandTable> tracks = const {},
}) {
  var tree = child;
  if (table != null) {
    tree = ReactiveScope(table: table, tracks: tracks, child: tree);
  }
  return Directionality(
    textDirection: TextDirection.ltr,
    child: FrameProvider(
      frame: frame,
      child: TimeScopeProvider(scope: _scope, child: tree),
    ),
  );
}

void main() {
  group('FrameBuilder — builds with a live FrameContext (WI-17)', () {
    testWidgets('hands the builder a FrameContext and renders its widget', (tester) async {
      late FrameContext seen;
      await tester.pumpWidget(
        _host(
          FrameBuilder((ctx) {
            seen = ctx;
            return Text('frame ${ctx.frame}');
          }),
          frame: 12,
        ),
      );
      expect(seen.frame, 12);
      expect(find.text('frame 12'), findsOneWidget);
    });

    testWidgets('progress reads the window position', (tester) async {
      late double progress;
      await tester.pumpWidget(
        _host(
          FrameBuilder((ctx) {
            progress = ctx.progress;
            return const SizedBox();
          }),
          frame: 30, // halfway across the 60-frame window
        ),
      );
      expect(progress, closeTo(0.5, 1e-9));
    });

    testWidgets('rebuilds with the new frame when the clock advances', (tester) async {
      Widget build(int frame) => _host(
        FrameBuilder((ctx) => Text('f=${ctx.frame}')),
        frame: frame,
      );
      await tester.pumpWidget(build(5));
      expect(find.text('f=5'), findsOneWidget);
      await tester.pumpWidget(build(20));
      expect(find.text('f=20'), findsOneWidget);
      expect(find.text('f=5'), findsNothing);
    });
  });

  group('FrameBuilder — a CustomPaint from ctx.progress renders (WI-17)', () {
    testWidgets('paints without error', (tester) async {
      await tester.pumpWidget(
        _host(
          FrameBuilder(
            (ctx) => CustomPaint(
              size: const Size(40, 40),
              painter: _ProgressBar(ctx.progress),
            ),
          ),
          frame: 30,
        ),
      );
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('FrameBuilder — ctx.audio reads a tagged track (WI-17, §14.4)', () {
    testWidgets('reads the committed band-table fixture for a track', (tester) async {
      final beat = Anchor('beat');
      // A known fixture: bass climbs across three frames on the tagged track.
      final trackTable = BandTable({
        AudioBand.bass: Float64List.fromList([0.0, 0.6, 1.0]),
      });
      late double bass;
      await tester.pumpWidget(
        _host(
          FrameBuilder((ctx) {
            bass = ctx.audio(beat);
            return const SizedBox();
          }),
          frame: 1,
          table: BandTable({
            AudioBand.bass: Float64List.fromList([0.0, 0.0, 0.0]),
          }),
          tracks: {beat: trackTable},
        ),
      );
      expect(bass, closeTo(0.6, 1e-9)); // tagged track's bass[1]
    });
  });
}

/// A trivial painter whose fill width tracks `progress`, proving a FrameBuilder
/// subject can paint from the resolved context.
class _ProgressBar extends CustomPainter {
  const _ProgressBar(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF6C5CE7);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width * progress, size.height), paint);
  }

  @override
  bool shouldRepaint(_ProgressBar oldDelegate) => oldDelegate.progress != progress;
}
