import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/stagger.dart';
import 'package:fluvie/src/core/stagger_origin.dart';
import 'package:fluvie/src/core/time.dart';

/// Exhaustive switch over the sealed hierarchy: a new variant without a case
/// breaks compilation.
String _describe(Stagger stagger) => switch (stagger) {
  EachStagger() => 'each',
  EvenlyStagger() => 'evenly',
  OriginStagger() => 'from',
};

void main() {
  group('Stagger.each', () {
    test('stores its per-child gap', () {
      const stagger = Stagger.each(Time.ms(80));
      expect((stagger as EachStagger).gap, const Time.ms(80));
    });

    test('value equality and hashCode', () {
      const a = Stagger.each(Time.ms(80));
      const b = Stagger.each(Time.ms(80));
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(const Stagger.each(Time.ms(90)))));
    });

    test('toString names the gap', () {
      expect(const Stagger.each(Time.ms(80)).toString(), contains('Time.ms(80)'));
      expect(const Stagger.each(Time.ms(80)).toString(), contains('each'));
    });
  });

  group('Stagger.evenly', () {
    test('stores the total span', () {
      const stagger = Stagger.evenly(over: Time.relative(0.5));
      expect((stagger as EvenlyStagger).over, const Time.relative(0.5));
    });

    test('value equality and hashCode', () {
      const a = Stagger.evenly(over: Time.seconds(0.5));
      const b = Stagger.evenly(over: Time.seconds(0.5));
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(const Stagger.evenly(over: Time.seconds(0.6)))));
    });

    test('toString names the span', () {
      expect(const Stagger.evenly(over: Time.seconds(0.5)).toString(), contains('evenly'));
      expect(
        const Stagger.evenly(over: Time.seconds(0.5)).toString(),
        contains('Time.seconds(0.5)'),
      );
    });
  });

  group('Stagger.from', () {
    test('stores the origin; gap defaults to null (resolver decides)', () {
      const stagger = Stagger.from(StaggerOrigin.center);
      expect((stagger as OriginStagger).origin, StaggerOrigin.center);
      expect(stagger.gap, isNull);
    });

    test('accepts an explicit gap', () {
      const stagger = Stagger.from(StaggerOrigin.edges, gap: Time.ms(60));
      expect((stagger as OriginStagger).gap, const Time.ms(60));
    });

    test('value equality and hashCode', () {
      const a = Stagger.from(StaggerOrigin.center, gap: Time.ms(60));
      const b = Stagger.from(StaggerOrigin.center, gap: Time.ms(60));
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(const Stagger.from(StaggerOrigin.edges, gap: Time.ms(60)))));
      expect(a, isNot(equals(const Stagger.from(StaggerOrigin.center, gap: Time.ms(50)))));
      expect(a, isNot(equals(const Stagger.from(StaggerOrigin.center))));
    });

    test('toString names the origin', () {
      expect(const Stagger.from(StaggerOrigin.center).toString(), contains('center'));
      expect(
        const Stagger.from(StaggerOrigin.edges, gap: Time.ms(60)).toString(),
        contains('Time.ms(60)'),
      );
    });
  });

  group('Stagger hierarchy', () {
    test('variants are mutually unequal', () {
      const each = Stagger.each(Time.ms(80));
      const evenly = Stagger.evenly(over: Time.ms(80));
      const from = Stagger.from(StaggerOrigin.start, gap: Time.ms(80));
      expect(each, isNot(equals(evenly)));
      expect(each, isNot(equals(from)));
      expect(evenly, isNot(equals(from)));
    });

    test('a switch over the sealed hierarchy is exhaustive', () {
      expect(_describe(const Stagger.each(Time.ms(80))), 'each');
      expect(_describe(const Stagger.evenly(over: Time.seconds(1))), 'evenly');
      expect(_describe(const Stagger.from(StaggerOrigin.center)), 'from');
    });
  });
}
