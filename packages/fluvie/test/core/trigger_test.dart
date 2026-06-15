import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/trigger.dart';

/// An exhaustive switch over the sealed hierarchy: if a subtype is added
/// without a case, this no longer compiles.
String _describe(Trigger trigger) => switch (trigger) {
  AutoTrigger() => 'auto',
  SceneStartTrigger() => 'sceneStart',
  SceneEndTrigger() => 'sceneEnd',
  PreviousTrigger() => 'previous',
  AbsoluteTrigger(:final time) => 'at($time)',
  BeatTrigger(:final every) => 'beat($every)',
  AfterTrigger(:final anchor) => 'after($anchor)',
  WhenStartsTrigger(:final anchor) => 'whenStarts($anchor)',
};

void main() {
  group('Trigger singletons', () {
    test('the four const singletons are canonical instances', () {
      expect(identical(Trigger.auto, const AutoTrigger()), isTrue);
      expect(identical(Trigger.sceneStart, const SceneStartTrigger()), isTrue);
      expect(identical(Trigger.sceneEnd, const SceneEndTrigger()), isTrue);
      expect(identical(Trigger.previous, const PreviousTrigger()), isTrue);
    });

    test('singletons are distinct from each other', () {
      expect(Trigger.auto, isNot(equals(Trigger.sceneStart)));
      expect(Trigger.sceneEnd, isNot(equals(Trigger.previous)));
    });

    test('singleton toStrings name the trigger', () {
      expect(Trigger.auto.toString(), contains('auto'));
      expect(Trigger.sceneStart.toString(), contains('sceneStart'));
      expect(Trigger.sceneEnd.toString(), contains('sceneEnd'));
      expect(Trigger.previous.toString(), contains('previous'));
    });
  });

  group('Trigger.at', () {
    test('is value-equal by Time', () {
      expect(const Trigger.at(Time.seconds(2)), equals(const Trigger.at(Time.seconds(2))));
      expect(
        const Trigger.at(Time.seconds(2)).hashCode,
        const Trigger.at(Time.seconds(2)).hashCode,
      );
      expect(const Trigger.at(Time.seconds(2)), isNot(equals(const Trigger.at(Time.seconds(3)))));
      expect(const Trigger.at(Time.frames(10)), isNot(equals(const Trigger.at(Time.ms(10)))));
    });

    test('exposes its time and names it in toString', () {
      const trigger = AbsoluteTrigger(Time.frames(12));
      expect(trigger.time, const Time.frames(12));
      expect(trigger.toString(), contains('Time.frames(12)'));
    });
  });

  group('Trigger.beat', () {
    test('every defaults to 1 and track to null', () {
      const trigger = BeatTrigger();
      expect(trigger.every, 1);
      expect(trigger.track, isNull);
    });

    test('is value-equal by every + track identity', () {
      final track = Anchor('beat');
      final other = Anchor('beat');
      expect(Trigger.beat(every: 2, track: track), equals(Trigger.beat(every: 2, track: track)));
      expect(
        Trigger.beat(every: 2, track: track).hashCode,
        Trigger.beat(every: 2, track: track).hashCode,
      );
      expect(
        Trigger.beat(every: 2, track: track),
        isNot(equals(Trigger.beat(every: 3, track: track))),
      );
      // Same debugName, different anchor instance: NOT equal (identity).
      expect(
        Trigger.beat(every: 2, track: track),
        isNot(equals(Trigger.beat(every: 2, track: other))),
      );
      var every = 1; // runtime value so the analyzer can't fold the comparison
      expect(const Trigger.beat(), equals(Trigger.beat(every: every)));
      every = 2;
      expect(const Trigger.beat(), isNot(equals(Trigger.beat(every: every))));
    });

    test('toString names every and the track', () {
      final trigger = Trigger.beat(every: 4, track: Anchor('drums'));
      expect(trigger.toString(), contains('4'));
      expect(trigger.toString(), contains('drums'));
    });
  });

  group('Trigger.after / Trigger.whenStarts', () {
    test('are value-equal by anchor identity', () {
      final a = Anchor('x');
      final b = Anchor('x');
      expect(Trigger.after(a), equals(Trigger.after(a)));
      expect(Trigger.after(a).hashCode, Trigger.after(a).hashCode);
      expect(Trigger.after(a), isNot(equals(Trigger.after(b))));
      expect(Trigger.whenStarts(a), equals(Trigger.whenStarts(a)));
      expect(Trigger.whenStarts(a), isNot(equals(Trigger.whenStarts(b))));
    });

    test('after and whenStarts on the same anchor are different triggers', () {
      final a = Anchor('x');
      expect(Trigger.after(a), isNot(equals(Trigger.whenStarts(a))));
    });

    test('expose their anchor and name it in toString', () {
      final a = Anchor('bg');
      expect((Trigger.after(a) as AfterTrigger).anchor, same(a));
      expect((Trigger.whenStarts(a) as WhenStartsTrigger).anchor, same(a));
      expect(Trigger.after(a).toString(), contains('bg'));
      expect(Trigger.whenStarts(a).toString(), contains('bg'));
    });
  });

  group('Trigger hierarchy', () {
    test('a switch over all subtypes is exhaustive and dispatches correctly', () {
      final anchor = Anchor('a');
      expect(_describe(Trigger.auto), 'auto');
      expect(_describe(Trigger.sceneStart), 'sceneStart');
      expect(_describe(Trigger.sceneEnd), 'sceneEnd');
      expect(_describe(Trigger.previous), 'previous');
      expect(_describe(const Trigger.at(Time.frames(3))), 'at(Time.frames(3))');
      expect(_describe(const Trigger.beat(every: 2)), 'beat(2)');
      expect(_describe(Trigger.after(anchor)), 'after($anchor)');
      expect(_describe(Trigger.whenStarts(anchor)), 'whenStarts($anchor)');
    });
  });

  group('marker trigger value equality', () {
    // Builds at run time so const canonicalization cannot make the instances
    // identical -- the equality under test must be structural.
    T runtime<T>(T Function() build) => build();

    test('non-const instances equal the canonical const singletons', () {
      expect(runtime(AutoTrigger.new), Trigger.auto);
      expect(runtime(SceneStartTrigger.new), Trigger.sceneStart);
      expect(runtime(SceneEndTrigger.new), Trigger.sceneEnd);
      expect(runtime(PreviousTrigger.new), Trigger.previous);
    });

    test('marker types stay distinct from each other', () {
      expect(Trigger.auto, isNot(Trigger.sceneStart));
      expect(Trigger.sceneEnd, isNot(Trigger.previous));
    });

    test('hashCodes agree with equality', () {
      expect(runtime(AutoTrigger.new).hashCode, Trigger.auto.hashCode);
    });
  });
}
