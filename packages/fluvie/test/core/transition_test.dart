import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/painting.dart' show Alignment;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/edge.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/transition.dart';

void main() {
  group('Transition factories (D2, §13)', () {
    test('cut is const, zero duration, overlap false, variant params null', () {
      const cut = Transition.cut();
      expect(identical(cut, const Transition.cut()), isTrue);
      expect(cut.kind, TransitionKind.cut);
      expect(cut.duration, Time.zero);
      expect(cut.overlap, isFalse);
      expect(cut.ease, same(Ease.linear));
      expect(cut.direction, isNull);
      expect(cut.into, isNull);
      expect(cut.from, isNull);
    });

    test('crossFade carries its duration with overlap true and ease linear by default', () {
      final t = Transition.crossFade(0.5.seconds);
      expect(t.kind, TransitionKind.crossFade);
      expect(t.duration, 0.5.seconds);
      expect(t.overlap, isTrue);
      expect(t.ease, same(Ease.linear));
      expect(t.direction, isNull);
      expect(t.into, isNull);
      expect(t.from, isNull);
    });

    test('crossFade accepts explicit overlap and ease', () {
      final t = Transition.crossFade(10.frames, overlap: false, ease: Ease.smooth);
      expect(t.overlap, isFalse);
      expect(t.ease, same(Curves.easeInOut));
    });

    test('wipe defaults its travel direction to Edge.right', () {
      final t = Transition.wipe(0.4.seconds);
      expect(t.kind, TransitionKind.wipe);
      expect(t.duration, 0.4.seconds);
      expect(t.direction, Edge.right);
      expect(t.overlap, isTrue);
      expect(t.ease, same(Ease.linear));
      expect(t.into, isNull);
      expect(t.from, isNull);
    });

    test('zoom defaults into to Alignment.center', () {
      final t = Transition.zoom(0.6.seconds);
      expect(t.kind, TransitionKind.zoom);
      expect(t.duration, 0.6.seconds);
      expect(t.into, Alignment.center);
      expect(t.overlap, isTrue);
      expect(t.ease, same(Ease.linear));
      expect(t.direction, isNull);
      expect(t.from, isNull);
    });

    test('slide defaults from to Edge.right', () {
      final t = Transition.slide(0.4.seconds);
      expect(t.kind, TransitionKind.slide);
      expect(t.duration, 0.4.seconds);
      expect(t.from, Edge.right);
      expect(t.overlap, isTrue);
      expect(t.ease, same(Ease.linear));
      expect(t.direction, isNull);
      expect(t.into, isNull);
    });
  });

  group('Transition equality (D2/D23)', () {
    test('same factory, same fields: equal values, equal hashCodes', () {
      expect(Transition.crossFade(0.5.seconds), Transition.crossFade(0.5.seconds));
      expect(
        Transition.crossFade(0.5.seconds).hashCode,
        Transition.crossFade(0.5.seconds).hashCode,
      );
      expect(
        Transition.wipe(12.frames, direction: Edge.left),
        Transition.wipe(12.frames, direction: Edge.left),
      );
      expect(
        Transition.zoom(18.frames, into: Alignment.topRight),
        Transition.zoom(18.frames, into: Alignment.topRight),
      );
      expect(
        Transition.slide(12.frames, from: Edge.top),
        Transition.slide(12.frames, from: Edge.top),
      );
      expect(const Transition.cut(), const Transition.cut());
    });

    test('different duration, overlap, or ease: not equal', () {
      expect(Transition.crossFade(0.5.seconds), isNot(Transition.crossFade(0.4.seconds)));
      expect(
        Transition.crossFade(0.5.seconds),
        isNot(Transition.crossFade(0.5.seconds, overlap: false)),
      );
      expect(
        Transition.crossFade(0.5.seconds),
        isNot(Transition.crossFade(0.5.seconds, ease: Ease.smooth)),
      );
    });

    test('curve equality is identity: the same Ease singleton compares equal (D23)', () {
      expect(
        Transition.crossFade(10.frames, ease: Ease.smooth),
        Transition.crossFade(10.frames, ease: Curves.easeInOut),
      );
    });

    test('different kinds with the same duration: not equal', () {
      expect(Transition.crossFade(12.frames), isNot(Transition.zoom(12.frames)));
      expect(Transition.wipe(12.frames), isNot(Transition.slide(12.frames)));
    });

    test('different variant params: not equal within a kind', () {
      expect(
        Transition.wipe(12.frames, direction: Edge.left),
        isNot(Transition.wipe(12.frames)),
      );
      expect(
        Transition.zoom(12.frames, into: Alignment.topLeft),
        isNot(Transition.zoom(12.frames)),
      );
      expect(
        Transition.slide(12.frames, from: Edge.bottom),
        isNot(Transition.slide(12.frames)),
      );
    });
  });

  group('Transition toString', () {
    test('is stable per kind (ease omitted: curve singletons have no stable text)', () {
      expect(const Transition.cut().toString(), 'Transition.cut()');
      expect(
        Transition.crossFade(0.5.seconds).toString(),
        'Transition.crossFade(Time.seconds(0.5), overlap: true)',
      );
      expect(
        Transition.wipe(12.frames, overlap: false).toString(),
        'Transition.wipe(Time.frames(12), direction: Edge.right, overlap: false)',
      );
      expect(
        Transition.zoom(18.frames).toString(),
        'Transition.zoom(Time.frames(18), into: Alignment.center, overlap: true)',
      );
      expect(
        Transition.slide(12.frames, from: Edge.left).toString(),
        'Transition.slide(Time.frames(12), from: Edge.left, overlap: true)',
      );
    });
  });
}
