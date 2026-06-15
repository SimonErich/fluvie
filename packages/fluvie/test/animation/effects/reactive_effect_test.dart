import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/effects/reactive_effect.dart';
import 'package:fluvie/src/animation/runtime/reactive_scope.dart';
import 'package:fluvie/src/core/audio/band_table.dart';
import 'package:fluvie/src/core/audio_band.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';

BandTable _table() => BandTable({
  AudioBand.bass: Float64List.fromList([0.0, 0.5, 1.0]),
  AudioBand.mid: Float64List.fromList([0.2, 0.2, 0.2]),
  AudioBand.treble: Float64List.fromList([0.0, 0.0, 0.0]),
});

/// Mounts [effect] over a keyed child at [frame], optionally under a
/// [ReactiveScope] carrying [table], optionally in capture [mode].
Future<void> _pump(
  WidgetTester tester, {
  required ReactiveEffect effect,
  required int frame,
  required GlobalKey childKey,
  BandTable? table,
  RenderMode mode = RenderMode.preview,
}) async {
  var tree = effect.build(SizedBox(key: childKey, width: 100, height: 100), 0);
  tree = FrameProvider(frame: frame, child: tree);
  if (table != null) {
    tree = ReactiveScope(table: table, child: tree);
  }
  tree = RenderModeContext(
    mode: mode,
    child: Directionality(textDirection: TextDirection.ltr, child: tree),
  );
  await tester.pumpWidget(tree);
}

/// The Y scale a `Transform` applies to the child below [key].
double _scaleY(WidgetTester tester, GlobalKey key) {
  final transform = tester.widget<Transform>(
    find.ancestor(of: find.byKey(key), matching: find.byType(Transform)).first,
  );
  return transform.transform.getColumn(1)[1];
}

void main() {
  group('ReactiveEffect.scaleY', () {
    testWidgets('scales the child Y by energyAt * gain at the probed frame', (tester) async {
      final childKey = GlobalKey();
      await _pump(
        tester,
        effect: const ReactiveEffect(mode: ReactiveMode.scaleY, band: AudioBand.bass, gain: 2),
        frame: 2, // bass energy 1.0 at frame 2
        childKey: childKey,
        table: _table(),
      );
      // 1 + energy(1.0) * gain(2) = 3.0 (scaleY grows from the natural 1).
      expect(_scaleY(tester, childKey), closeTo(3.0, 1e-9));
    });

    testWidgets('is neutral (scale 1) when energy is zero', (tester) async {
      final childKey = GlobalKey();
      await _pump(
        tester,
        effect: const ReactiveEffect(mode: ReactiveMode.scaleY, band: AudioBand.bass),
        frame: 0, // bass energy 0.0 at frame 0
        childKey: childKey,
        table: _table(),
      );
      expect(_scaleY(tester, childKey), closeTo(1.0, 1e-9));
    });
  });

  group('ReactiveEffect.pulse', () {
    testWidgets('scales the child uniformly by 1 + energy * gain', (tester) async {
      final childKey = GlobalKey();
      await _pump(
        tester,
        effect: const ReactiveEffect(mode: ReactiveMode.pulse, band: AudioBand.bass, gain: 2),
        frame: 1, // bass energy 0.5 at frame 1
        childKey: childKey,
        table: _table(),
      );
      final transform = tester.widget<Transform>(
        find.ancestor(of: find.byKey(childKey), matching: find.byType(Transform)).first,
      );
      // Uniform: x and y scales both 1 + 0.5 * 2 = 2.0.
      expect(transform.transform.getColumn(0)[0], closeTo(2.0, 1e-9));
      expect(transform.transform.getColumn(1)[1], closeTo(2.0, 1e-9));
    });
  });

  group('capture without a ReactiveScope', () {
    testWidgets('throws a FluvieRenderException naming the band and precompute', (tester) async {
      final childKey = GlobalKey();
      await _pump(
        tester,
        effect: const ReactiveEffect(mode: ReactiveMode.scaleY, band: AudioBand.bass),
        frame: 0,
        childKey: childKey,
        mode: RenderMode.capture,
      );
      final error = tester.takeException();
      expect(error, isA<FluvieRenderException>());
      expect(error.toString(), contains('bass'));
      expect(error.toString().toLowerCase(), contains('precompute'));
    });
  });

  group('preview without a ReactiveScope', () {
    testWidgets('falls back to the neutral (energy 0) state', (tester) async {
      final childKey = GlobalKey();
      await _pump(
        tester,
        effect: const ReactiveEffect(mode: ReactiveMode.scaleY, band: AudioBand.bass, gain: 3),
        frame: 2,
        childKey: childKey,
      );
      // No scope -> energy 0 -> scaleY 1.0. The child still renders.
      expect(find.byKey(childKey), findsOneWidget);
      expect(_scaleY(tester, childKey), closeTo(1.0, 1e-9));
      expect(tester.takeException(), isNull);
    });
  });

  group('ReactiveScope.tableFor', () {
    testWidgets('returns the default table when no anchor is given', (tester) async {
      late BandTable? resolved;
      await tester.pumpWidget(
        ReactiveScope(
          table: _table(),
          child: Builder(
            builder: (context) {
              resolved = ReactiveScope.tableFor(context, null);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(resolved, _table());
    });

    testWidgets('returns null when no scope is present', (tester) async {
      late BandTable? resolved;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            resolved = ReactiveScope.tableFor(context, null);
            return const SizedBox();
          },
        ),
      );
      expect(resolved, isNull);
    });
  });
}
