import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/spring_solver.dart';
import 'package:fluvie/src/core/timing.dart';

/// All four presets plus the package default (all underdamped).
const presets = <String, Spring>{
  'default': Spring(),
  'gentle': Spring.gentle,
  'snappy': Spring.snappy,
  'bouncy': Spring.bouncy,
  'stiff': Spring.stiff,
};

/// ζ = 1.5: cmk = 900 − 400 > 0.
const overdamped = Spring(stiffness: 100, damping: 30);

/// ζ = 1 exactly: cmk = 400 − 400 == 0.
const criticallyDamped = Spring(stiffness: 100, damping: 20);

const all = <String, Spring>{
  ...presets,
  'overdamped': overdamped,
  'critical': criticallyDamped,
  'withVelocity': Spring(initialVelocity: 5),
};

SpringSimulation _reference(Spring s) => SpringSimulation(
  SpringDescription(mass: s.mass, stiffness: s.stiffness, damping: s.damping),
  1,
  0,
  s.initialVelocity,
);

void main() {
  group('SpringSolver initial conditions', () {
    for (final MapEntry(key: name, value: spring) in all.entries) {
      test('$name: value(0) == 1 and velocity(0) == initialVelocity', () {
        final solver = SpringSolver(spring);
        expect(solver.value(0), 1.0);
        expect(solver.velocity(0), closeTo(spring.initialVelocity, 1e-9));
      });
    }
  });

  group('SpringSolver matches package:flutter/physics SpringSimulation', () {
    for (final MapEntry(key: name, value: spring) in all.entries) {
      test('$name: value and velocity agree to 1e-6 over t = 0.05..1.0', () {
        final solver = SpringSolver(spring);
        final sim = _reference(spring);
        for (var i = 1; i <= 20; i++) {
          final t = i * 0.05;
          expect(solver.value(t), closeTo(sim.x(t), 1e-6), reason: '$name value at t=$t');
          expect(solver.velocity(t), closeTo(sim.dx(t), 1e-6), reason: '$name velocity at t=$t');
        }
      });
    }
  });

  group('SpringSolver.settleTime', () {
    for (final MapEntry(key: name, value: spring) in all.entries) {
      test('$name: displacement stays within epsilon forever after settle', () {
        final solver = SpringSolver(spring);
        final settle = solver.settleTime();
        expect(settle, greaterThan(0));
        final omega = math.sqrt(spring.stiffness / spring.mass);
        for (final dt in [1e-9, 0.001, 0.01, 0.1, 0.5, 1.0, 10.0]) {
          final t = settle + dt;
          expect(solver.value(t).abs(), lessThanOrEqualTo(0.001), reason: '$name at t=$t');
          expect(
            solver.velocity(t).abs() / omega,
            lessThanOrEqualTo(0.001),
            reason: '$name scaled velocity at t=$t',
          );
        }
      });
    }

    test('a tighter epsilon settles strictly later', () {
      final solver = SpringSolver(Spring.bouncy);
      expect(solver.settleTime(epsilon: 0.0001), greaterThan(solver.settleTime()));
    });

    for (final MapEntry(key: name, value: spring) in {
      'critical': criticallyDamped,
      'overdamped': overdamped,
    }.entries) {
      test('$name: decays monotonically from 1 to settle', () {
        final solver = SpringSolver(spring);
        final settle = solver.settleTime();
        var previous = solver.value(0);
        for (var i = 1; i <= 200; i++) {
          final value = solver.value(settle * i / 200);
          expect(value, lessThanOrEqualTo(previous + 1e-12), reason: '$name step $i');
          expect(value, greaterThanOrEqualTo(0), reason: '$name step $i');
          previous = value;
        }
      });
    }
  });

  group('SpringSolver.settleFrames', () {
    for (final MapEntry(key: name, value: spring) in all.entries) {
      test('$name: is ceil(settleTime * fps) at 30 and 60 fps', () {
        final solver = SpringSolver(spring);
        expect(solver.settleFrames(30), (solver.settleTime() * 30).ceil());
        expect(solver.settleFrames(60), (solver.settleTime() * 60).ceil());
        expect(
          solver.settleFrames(30, epsilon: 0.01),
          (solver.settleTime(epsilon: 0.01) * 30).ceil(),
        );
      });
    }
  });

  group('SpringSolver determinism', () {
    test('two solvers over the same spring produce identical outputs', () {
      final a = SpringSolver(Spring.bouncy);
      final b = SpringSolver(Spring.bouncy);
      for (final t in [0.0, 0.1, 0.37, 1.0, 5.0]) {
        expect(a.value(t), b.value(t));
        expect(a.velocity(t), b.velocity(t));
      }
      expect(a.settleTime(), b.settleTime());
      expect(a.settleFrames(30), b.settleFrames(30));
    });
  });

  group('zero damping (never settles)', () {
    test('settleTime throws an ArgumentError naming the spring', () {
      final solver = SpringSolver(const Spring(damping: 0));

      expect(
        solver.settleTime,
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('oscillates forever'),
          ),
        ),
      );
    });

    test('settleFrames surfaces the same error', () {
      final solver = SpringSolver(const Spring(damping: 0));

      expect(() => solver.settleFrames(30), throwsArgumentError);
    });

    test('value and velocity stay computable without settling', () {
      final solver = SpringSolver(const Spring(damping: 0));

      expect(solver.value(0), 1.0);
      expect(solver.value(10).isFinite, isTrue);
      expect(solver.velocity(10).isFinite, isTrue);
    });
  });
}
