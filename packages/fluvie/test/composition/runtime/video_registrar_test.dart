import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/runtime/video_registrar.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/timing/resolver/trigger_resolver.dart';
import 'package:fluvie/src/timing/schedule/element_registration.dart';
import 'package:fluvie/src/timing/schedule/element_schedule.dart';

ElementRegistration _token([String owner = 'Box']) => ElementRegistration(debugOwner: owner);

const _schedule = ElementSchedule(
  window: ResolvedSpan(0, 60),
  spans: [],
  defaults: Defaults(duration: Time.frames(10)),
);

void main() {
  group('VideoRegistrar — collect pass (WI-16, D1)', () {
    test('register returns null and appends in registration order', () {
      final registrar = VideoRegistrar(sceneCount: 2);
      final first = _token('a');
      final second = _token('b');
      final third = _token('c');
      expect(registrar.isResolved, isFalse);
      expect(registrar.forScene(0).register(first), isNull);
      expect(registrar.forScene(0).register(second), isNull);
      expect(registrar.forScene(1).register(third), isNull);
      expect(registrar.registrationsByScene[0], [same(first), same(second)]);
      expect(registrar.registrationsByScene[1], [same(third)]);
    });

    test('re-registering the same token during collect is idempotent', () {
      final registrar = VideoRegistrar(sceneCount: 1);
      final token = _token();
      registrar.forScene(0).register(token);
      registrar.forScene(0).register(token);
      expect(registrar.registrationsByScene[0], hasLength(1));
    });

    test('the per-scene facade tags its scene index', () {
      final registrar = VideoRegistrar(sceneCount: 3);
      final token = _token();
      registrar.forScene(2).register(token);
      expect(registrar.registrationsByScene[0], isEmpty);
      expect(registrar.registrationsByScene[1], isEmpty);
      expect(registrar.registrationsByScene[2], [same(token)]);
    });

    test('forScene returns a fresh facade per call — pass-2 notification rides identity', () {
      final registrar = VideoRegistrar(sceneCount: 1);
      expect(identical(registrar.forScene(0), registrar.forScene(0)), isFalse);
    });

    test('forScene rejects an out-of-range scene index', () {
      final registrar = VideoRegistrar(sceneCount: 1);
      expect(() => registrar.forScene(1), throwsA(isA<AssertionError>()));
      expect(() => registrar.forScene(-1), throwsA(isA<AssertionError>()));
    });
  });

  group('VideoRegistrar — resolution (WI-16, D1/D3)', () {
    test('after resolveWith, known tokens get their schedules back', () {
      final registrar = VideoRegistrar(sceneCount: 1);
      final token = _token();
      final facade = registrar.forScene(0)..register(token);
      registrar.resolveWith({token: _schedule});
      expect(registrar.isResolved, isTrue);
      expect(facade.isResolved, isTrue);
      expect(facade.register(token), same(_schedule));
    });

    test('an unknown token after resolution throws the D3 stable-set error', () {
      final registrar = VideoRegistrar(sceneCount: 1);
      final known = _token('known');
      registrar.forScene(0).register(known);
      registrar.resolveWith({known: _schedule});
      expect(
        () => registrar.forScene(0).register(_token('late')),
        throwsA(
          isA<FluvieTimingError>()
              .having((e) => e.message, 'message', contains('stable across frames'))
              .having((e) => e.message, 'message', contains('.show()')),
        ),
      );
    });

    test('unregister then re-register the same token post-resolution survives a remount', () {
      final registrar = VideoRegistrar(sceneCount: 1);
      final token = _token();
      final facade = registrar.forScene(0)..register(token);
      registrar.resolveWith({token: _schedule});
      facade.unregister(token);
      expect(registrar.registrationsByScene[0], isEmpty);
      expect(facade.register(token), same(_schedule));
      expect(registrar.registrationsByScene[0], [same(token)]);
    });

    test('unregister before resolution merely removes the token', () {
      final registrar = VideoRegistrar(sceneCount: 1);
      final token = _token();
      registrar.forScene(0)
        ..register(token)
        ..unregister(token);
      expect(registrar.registrationsByScene[0], isEmpty);
    });

    test('unregistering an unknown token is silently ignored', () {
      final registrar = VideoRegistrar(sceneCount: 1);
      expect(() => registrar.forScene(0).unregister(_token()), returnsNormally);
    });
  });

  group('VideoRegistrar — reset (WI-16, D6)', () {
    test('reset clears registrations, schedules, and the resolved flag', () {
      final registrar = VideoRegistrar(sceneCount: 1);
      final token = _token();
      registrar.forScene(0).register(token);
      registrar
        ..resolveWith({token: _schedule})
        ..reset();
      expect(registrar.isResolved, isFalse);
      expect(registrar.registrationsByScene[0], isEmpty);
      // The next collect generation starts from scratch.
      expect(registrar.forScene(0).register(token), isNull);
    });

    test('reset can resize for a new scenes list', () {
      final registrar = VideoRegistrar(sceneCount: 1)..reset(sceneCount: 3);
      expect(registrar.registrationsByScene, hasLength(3));
    });
  });
}
