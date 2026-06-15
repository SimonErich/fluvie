// WI-16: FrameContext exposes the resolved frame clock, window progress, fps,
// scope, the seeded noise source, and the analysed audio bands — closing the
// Phase 13 ctx.audio deferral. Capture without a ReactiveScope throws; preview
// returns 0.
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/runtime/frame_context.dart';
import 'package:fluvie/src/animation/runtime/noise_scope.dart';
import 'package:fluvie/src/animation/runtime/reactive_scope.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/audio/band_table.dart';
import 'package:fluvie/src/core/audio_band.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/core/noise/noise_source.dart';
import 'package:fluvie/src/core/noise/value_noise.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';

class _FakeNoise implements NoiseSource {
  const _FakeNoise();

  @override
  double valueForSeed(String seed) => 0.77;

  @override
  double noise1(double x) => 0.77;

  @override
  double noise2(double x, double y) => 0.77;
}

BandTable _table() => BandTable({
  AudioBand.bass: Float64List.fromList([0.0, 0.5, 1.0]),
  AudioBand.mid: Float64List.fromList([0.1, 0.2, 0.3]),
  AudioBand.treble: Float64List.fromList([0.9, 0.8, 0.7]),
});

/// Mounts a [FrameProvider]+[TimeScopeProvider] (and optionally a
/// [ReactiveScope]/[NoiseScope]/[RenderModeContext]) and hands the built
/// [FrameContext] to [body].
Future<void> _pump(
  WidgetTester tester, {
  required void Function(FrameContext ctx) body,
  int frame = 0,
  TimeScopeData scope = const TimeScopeData(fps: 30, startFrame: 0, durationFrames: 60),
  BandTable? table,
  Map<Anchor, BandTable> tracks = const {},
  NoiseSource? noise,
  RenderMode mode = RenderMode.preview,
}) async {
  Widget reader = Builder(
    builder: (context) {
      body(FrameContext(context));
      return const SizedBox();
    },
  );
  if (noise != null) {
    reader = NoiseScope(source: noise, child: reader);
  }
  if (table != null) {
    reader = ReactiveScope(table: table, tracks: tracks, child: reader);
  }
  reader = FrameProvider(
    frame: frame,
    child: TimeScopeProvider(scope: scope, child: reader),
  );
  reader = RenderModeContext(
    mode: mode,
    child: Directionality(textDirection: TextDirection.ltr, child: reader),
  );
  await tester.pumpWidget(reader);
}

void main() {
  group('FrameContext — clocks (WI-16)', () {
    testWidgets('frame reads the FrameProvider', (tester) async {
      late int frame;
      await _pump(tester, frame: 7, body: (ctx) => frame = ctx.frame);
      expect(frame, 7);
    });

    testWidgets('fps reads the scope', (tester) async {
      late int fps;
      await _pump(
        tester,
        scope: const TimeScopeData(fps: 60, startFrame: 0, durationFrames: 60),
        body: (ctx) => fps = ctx.fps,
      );
      expect(fps, 60);
    });

    testWidgets('scope exposes startFrame and durationFrames', (tester) async {
      late TimeScopeData scope;
      await _pump(
        tester,
        scope: const TimeScopeData(fps: 30, startFrame: 12, durationFrames: 48),
        body: (ctx) => scope = ctx.scope,
      );
      expect(scope.startFrame, 12);
      expect(scope.durationFrames, 48);
    });
  });

  group('FrameContext — progress (WI-16)', () {
    testWidgets('is 0 at the window start', (tester) async {
      late double progress;
      await _pump(
        tester,
        frame: 10,
        scope: const TimeScopeData(fps: 30, startFrame: 10, durationFrames: 40),
        body: (ctx) => progress = ctx.progress,
      );
      expect(progress, 0.0);
    });

    testWidgets('is 0.5 halfway across the window', (tester) async {
      late double progress;
      await _pump(
        tester,
        frame: 30,
        scope: const TimeScopeData(fps: 30, startFrame: 10, durationFrames: 40),
        body: (ctx) => progress = ctx.progress,
      );
      expect(progress, closeTo(0.5, 1e-9));
    });

    testWidgets('clamps to 1 past the window end', (tester) async {
      late double progress;
      await _pump(
        tester,
        frame: 999,
        scope: const TimeScopeData(fps: 30, startFrame: 10, durationFrames: 40),
        body: (ctx) => progress = ctx.progress,
      );
      expect(progress, 1.0);
    });
  });

  group('FrameContext — noise (WI-16)', () {
    testWidgets('reads the NoiseScope source', (tester) async {
      late double value;
      await _pump(tester, noise: const _FakeNoise(), body: (ctx) => value = ctx.noise('petal-3'));
      expect(value, 0.77);
    });

    testWidgets('defaults to the const ValueNoise with no scope', (tester) async {
      late double value;
      await _pump(tester, body: (ctx) => value = ctx.noise('petal-3'));
      expect(value, const ValueNoise().valueForSeed('petal-3'));
    });
  });

  group('FrameContext — audio (WI-16, closes ctx.audio)', () {
    testWidgets('audio() reads the bass energy at the frame', (tester) async {
      late double bass;
      await _pump(tester, frame: 2, table: _table(), body: (ctx) => bass = ctx.audio(null));
      expect(bass, closeTo(1.0, 1e-9)); // bass[2] = 1.0
    });

    testWidgets('audioBand() reads mid energy at the frame', (tester) async {
      late double mid;
      await _pump(
        tester,
        frame: 1,
        table: _table(),
        body: (ctx) => mid = ctx.audioBand(null, AudioBand.mid),
      );
      expect(mid, closeTo(0.2, 1e-9)); // mid[1] = 0.2
    });

    testWidgets('audioBand() reads treble energy at the frame', (tester) async {
      late double treble;
      await _pump(
        tester,
        table: _table(),
        body: (ctx) => treble = ctx.audioBand(null, AudioBand.treble),
      );
      expect(treble, closeTo(0.9, 1e-9)); // treble[0] = 0.9 (frame 0)
    });

    testWidgets('audio() resolves a per-track table by anchor', (tester) async {
      final track = Anchor('beat');
      final trackTable = BandTable({
        AudioBand.bass: Float64List.fromList([0.4, 0.4, 0.4]),
      });
      late double bass;
      await _pump(
        tester,
        frame: 1,
        table: _table(),
        tracks: {track: trackTable},
        body: (ctx) => bass = ctx.audio(track),
      );
      expect(bass, closeTo(0.4, 1e-9));
    });
  });

  group('FrameContext — audio without a ReactiveScope (WI-16)', () {
    testWidgets('preview returns 0', (tester) async {
      late double bass;
      late double mid;
      await _pump(
        tester,
        body: (ctx) {
          bass = ctx.audio(null);
          mid = ctx.audioBand(null, AudioBand.mid);
        },
      );
      expect(bass, 0.0);
      expect(mid, 0.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('capture throws a FluvieRenderException naming the band and precompute', (
      tester,
    ) async {
      await _pump(
        tester,
        mode: RenderMode.capture,
        body: (ctx) => ctx.audio(null),
      );
      final error = tester.takeException();
      expect(error, isA<FluvieRenderException>());
      expect(error.toString(), contains('bass'));
      expect(error.toString().toLowerCase(), contains('precompute'));
    });

    testWidgets('capture audioBand throws naming the requested band', (tester) async {
      await _pump(
        tester,
        mode: RenderMode.capture,
        body: (ctx) => ctx.audioBand(null, AudioBand.treble),
      );
      final error = tester.takeException();
      expect(error, isA<FluvieRenderException>());
      expect(error.toString(), contains('treble'));
    });
  });
}
