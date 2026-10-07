import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

const _black = Color(0xFF000000);
const _white = Color(0xFFFFFFFF);
const _red = Color(0xFFFF0000);

GradientEditorValue _twoStop() => const GradientEditorValue(
  stops: [
    GradientEditorStop(offset: 0, color: _black),
    GradientEditorStop(offset: 1, color: _white),
  ],
);

void main() {
  group('GradientEditorValue', () {
    test('is a value: equal stops, kind, and angle compare equal', () {
      expect(_twoStop(), _twoStop());
      expect(_twoStop().hashCode, _twoStop().hashCode);
      expect(_twoStop(), isNot(_twoStop().copyWith(kind: GradientEditorKind.radial)));
      expect(_twoStop(), isNot(_twoStop().copyWith(angle: 90)));
    });
  });

  group('gradientColorAt', () {
    test('samples the exact stops at their offsets and lerps between', () {
      final value = _twoStop();
      expect(gradientColorAt(value, 0), _black);
      expect(gradientColorAt(value, 1), _white);
      final mid = gradientColorAt(value, 0.5);
      expect(mid.r, closeTo(0.5, 0.01));
      expect(mid.g, closeTo(0.5, 0.01));
    });

    test('clamps before the first and after the last stop', () {
      const inset = GradientEditorValue(
        stops: [
          GradientEditorStop(offset: 0.4, color: _red),
          GradientEditorStop(offset: 0.6, color: _white),
        ],
      );
      expect(gradientColorAt(inset, 0), _red);
      expect(gradientColorAt(inset, 1), _white);
    });
  });

  group('gradientStopAdded', () {
    test('inserts at the fraction with the interpolated color, sorted', () {
      final (value: added, :index) = gradientStopAdded(_twoStop(), 0.5);
      expect(index, 1);
      expect(added.stops, hasLength(3));
      expect(added.stops[1].offset, 0.5);
      expect(added.stops[1].color.r, closeTo(0.5, 0.01));
      expect([for (final stop in added.stops) stop.offset], [0, 0.5, 1]);
    });

    test('keeps untouched stops verbatim', () {
      final (value: added, index: _) = gradientStopAdded(_twoStop(), 0.25);
      expect(added.stops.first, const GradientEditorStop(offset: 0, color: _black));
      expect(added.stops.last, const GradientEditorStop(offset: 1, color: _white));
    });
  });

  group('gradientStopMoved', () {
    test('moves within 0..1 and never crosses a neighbor', () {
      final three = gradientStopAdded(_twoStop(), 0.5).value;
      expect(gradientStopMoved(three, 1, 0.8).stops[1].offset, 0.8);
      expect(
        gradientStopMoved(three, 1, 1.4).stops[1].offset,
        lessThanOrEqualTo(three.stops[2].offset),
      );
      expect(gradientStopMoved(three, 0, -0.5).stops[0].offset, 0);
      expect(
        gradientStopMoved(three, 2, 0.1).stops[2].offset,
        greaterThanOrEqualTo(three.stops[1].offset),
      );
    });
  });

  group('gradientStopRemoved', () {
    test('removes a middle stop and refuses to go below two', () {
      final three = gradientStopAdded(_twoStop(), 0.5).value;
      final removed = gradientStopRemoved(three, 1);
      expect(removed?.stops, hasLength(2));
      expect(gradientStopRemoved(_twoStop(), 0), isNull, reason: 'min two stops');
    });
  });
}
