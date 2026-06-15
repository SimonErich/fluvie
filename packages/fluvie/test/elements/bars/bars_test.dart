import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/runtime/reactive_scope.dart';
import 'package:fluvie/src/composition/transition/shared_element.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/audio/band_table.dart';
import 'package:fluvie/src/core/audio_band.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/elements/bars/bars.dart';
import 'package:fluvie/src/elements/bars/render/bars_painter.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';
import 'package:fluvie/src/theme/fluvie_tokens.dart';
import 'package:fluvie/src/theme/fluvie_tokens_scope.dart';

BandTable _table() => BandTable({
  AudioBand.bass: Float64List.fromList([0.0, 0.5, 1.0]),
  AudioBand.mid: Float64List.fromList([0.2, 0.2, 0.2]),
  AudioBand.treble: Float64List.fromList([0.1, 0.1, 0.1]),
});

Future<void> _pumpBars(
  WidgetTester tester,
  Bars bars, {
  required int frame,
  BandTable? table,
  RenderMode mode = RenderMode.preview,
  FluvieTokens? tokens,
}) async {
  Widget tree = SizedBox(width: 240, height: 120, child: bars);
  tree = FrameProvider(frame: frame, child: tree);
  if (table != null) {
    tree = ReactiveScope(table: table, child: tree);
  }
  if (tokens != null) {
    tree = FluvieTokensScope(tokens: tokens, child: tree);
  }
  tree = RenderModeContext(
    mode: mode,
    child: Directionality(textDirection: TextDirection.ltr, child: tree),
  );
  await tester.pumpWidget(tree);
}

BarsPainter _painter(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(of: find.byType(Bars), matching: find.byType(CustomPaint)).first,
  );
  return paint.painter! as BarsPainter;
}

void main() {
  group('Bars rendering', () {
    testWidgets('renders the requested number of bars', (tester) async {
      await _pumpBars(tester, const Bars(count: 8), frame: 2, table: _table());
      expect(_painter(tester).heights, hasLength(8));
    });

    testWidgets('bar height tracks the band energy at the frame', (tester) async {
      // Frame 0: bass 0.0; frame 2: bass 1.0. 3 bars maps one bar per band, so
      // the loud-bass frame has a taller max than the silent-bass frame.
      await _pumpBars(tester, const Bars(count: 3), frame: 0, table: _table());
      final quiet = _painter(tester).heights.reduce((a, b) => a > b ? a : b);
      await _pumpBars(tester, const Bars(count: 3), frame: 2, table: _table());
      final loud = _painter(tester).heights.reduce((a, b) => a > b ? a : b);
      expect(loud, greaterThan(quiet));
    });

    testWidgets('gain scales the bar heights', (tester) async {
      await _pumpBars(tester, const Bars(count: 6, gain: 0.5), frame: 2, table: _table());
      final low = _painter(tester).heights.reduce((a, b) => a > b ? a : b);
      await _pumpBars(tester, const Bars(count: 6, gain: 2), frame: 2, table: _table());
      final high = _painter(tester).heights.reduce((a, b) => a > b ? a : b);
      expect(high, greaterThan(low));
    });

    testWidgets('count > 3 splits the energy across sub-bands deterministically', (tester) async {
      await _pumpBars(tester, const Bars(count: 16), frame: 2, table: _table());
      final first = _painter(tester).heights;
      await _pumpBars(tester, const Bars(count: 16), frame: 2, table: _table());
      final second = _painter(tester).heights;
      expect(first, hasLength(16));
      expect(first, orderedEquals(second));
      // Not every bar is identical (a real spectrum, not one flat block).
      expect(first.toSet().length, greaterThan(1));
    });
  });

  group('Bars theming', () {
    testWidgets('colors from context.fluvie', (tester) async {
      const tokens = FluvieTokens.fallback();
      await _pumpBars(
        tester,
        const Bars(count: 4),
        frame: 1,
        table: _table(),
        tokens: tokens,
      );
      expect(_painter(tester).color, tokens.palette.colorAt(0));
    });
  });

  group('Bars determinism guards', () {
    testWidgets('capture without a ReactiveScope throws naming the band', (tester) async {
      await _pumpBars(tester, const Bars(count: 8), frame: 0, mode: RenderMode.capture);
      final error = tester.takeException();
      expect(error, isA<FluvieRenderException>());
      expect(error.toString(), contains('bass'));
    });

    testWidgets('preview without a scope renders flat (no throw)', (tester) async {
      await _pumpBars(tester, const Bars(count: 8), frame: 0);
      expect(tester.takeException(), isNull);
      expect(_painter(tester).heights, hasLength(8));
    });
  });

  group('Bars composition', () {
    testWidgets('shared wraps the bars in a SharedElement', (tester) async {
      final anchor = Anchor('bars');
      await _pumpBars(
        tester,
        Bars(count: 4, shared: anchor),
        frame: 1,
        table: _table(),
      );
      expect(find.byType(SharedElement), findsOneWidget);
    });

    testWidgets('no shared mounts no SharedElement', (tester) async {
      await _pumpBars(tester, const Bars(count: 4), frame: 1, table: _table());
      expect(find.byType(SharedElement), findsNothing);
    });
  });
}
