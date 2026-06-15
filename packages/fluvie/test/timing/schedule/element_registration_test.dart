import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/timing/plan/animation_plan.dart';
import 'package:fluvie/src/timing/schedule/element_registration.dart';

void main() {
  group('ElementRegistration (WI-9)', () {
    test('carries every field verbatim', () {
      final anchor = Anchor('bg');
      final window = 1.seconds.to(3.seconds);
      const animations = [AnimationPlan(phase: AnimationPhase.enter)];
      const defaults = Defaults(duration: Time.frames(10));
      final registration = ElementRegistration(
        debugOwner: 'bg',
        anchor: anchor,
        window: window,
        animations: animations,
        defaults: defaults,
      );
      expect(registration.debugOwner, 'bg');
      expect(registration.anchor, same(anchor));
      expect(registration.window, same(window));
      expect(registration.animations, same(animations));
      expect(registration.defaults, same(defaults));
    });

    test('animations and the optional fields default to empty / null', () {
      final registration = ElementRegistration(debugOwner: 'Text');
      expect(registration.animations, isEmpty);
      expect(registration.anchor, isNull);
      expect(registration.window, isNull);
      expect(registration.defaults, isNull);
    });

    test('two field-identical tokens are not equal — identity is the contract (D2)', () {
      final a = ElementRegistration(debugOwner: 'Text');
      final b = ElementRegistration(debugOwner: 'Text');
      expect(a == b, isFalse);
      expect(a == a, isTrue);
      expect(identical(a, a), isTrue);
      expect(a.hashCode == a.hashCode, isTrue);
    });

    test('toString names the owner for diagnostics', () {
      final registration = ElementRegistration(debugOwner: 'bg');
      expect(registration.toString(), contains('bg'));
    });
  });
}
