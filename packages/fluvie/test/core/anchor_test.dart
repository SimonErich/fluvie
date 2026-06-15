import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/anchor.dart';

void main() {
  group('Anchor', () {
    test('two anchors with the same debugName are NOT equal (reference identity)', () {
      final a = Anchor('x');
      final b = Anchor('x');
      expect(a, isNot(equals(b)));
      expect(identical(a, b), isFalse);
    });

    test('an anchor equals itself', () {
      final a = Anchor('logo');
      expect(a, equals(a));
      expect(identical(a, a), isTrue);
    });

    test('unnamed anchors are distinct too', () {
      final a = Anchor();
      final b = Anchor();
      expect(a, isNot(equals(b)));
      expect(a.debugName, isNull);
    });

    test('hashCode is stable for the same instance', () {
      final a = Anchor('beat');
      expect(a.hashCode, a.hashCode);
    });

    test('toString includes the debugName when present', () {
      expect(Anchor('intro').toString(), contains('intro'));
      expect(Anchor('intro').toString(), contains('Anchor'));
      expect(Anchor().toString(), contains('Anchor'));
    });

    test('works as a map key by identity', () {
      final a = Anchor('x');
      final b = Anchor('x');
      final timelines = <Anchor, int>{a: 1, b: 2};
      expect(timelines.length, 2);
      expect(timelines[a], 1);
      expect(timelines[b], 2);
    });
  });
}
