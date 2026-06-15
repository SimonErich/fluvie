import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/timing/schedule/composition_registrar.dart';
import 'package:fluvie/src/timing/schedule/composition_registrar_scope.dart';
import 'package:fluvie/src/timing/schedule/element_registration.dart';
import 'package:fluvie/src/timing/schedule/element_schedule.dart';

/// A registrar that records registrations and stays in collect mode.
final class _FakeRegistrar implements CompositionRegistrar {
  final List<ElementRegistration> registered = [];

  @override
  bool get isResolved => false;

  @override
  ElementSchedule? register(ElementRegistration registration) {
    registered.add(registration);
    return null;
  }

  @override
  void unregister(ElementRegistration registration) => registered.remove(registration);
}

void main() {
  group('CompositionRegistrarScope (WI-10)', () {
    testWidgets('maybeOf returns the nearest registrar — nearest wins', (tester) async {
      final outer = _FakeRegistrar();
      final inner = _FakeRegistrar();
      CompositionRegistrar? seen;
      await tester.pumpWidget(
        CompositionRegistrarScope(
          registrar: outer,
          child: CompositionRegistrarScope(
            registrar: inner,
            child: Builder(
              builder: (context) {
                seen = CompositionRegistrarScope.maybeOf(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(seen, same(inner));
    });

    testWidgets('maybeOf returns null when no scope is mounted', (tester) async {
      CompositionRegistrar? seen = _FakeRegistrar();
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            seen = CompositionRegistrarScope.maybeOf(context);
            return const SizedBox.shrink();
          },
        ),
      );
      expect(seen, isNull);
    });

    testWidgets('notifies dependents only when the registrar identity changes', (tester) async {
      final first = _FakeRegistrar();
      final second = _FakeRegistrar();
      var builds = 0;
      // The same child instance across pumps: it rebuilds only when notified.
      final probe = Builder(
        builder: (context) {
          CompositionRegistrarScope.maybeOf(context);
          builds++;
          return const SizedBox.shrink();
        },
      );
      await tester.pumpWidget(CompositionRegistrarScope(registrar: first, child: probe));
      expect(builds, 1);
      await tester.pumpWidget(CompositionRegistrarScope(registrar: first, child: probe));
      expect(builds, 1);
      await tester.pumpWidget(CompositionRegistrarScope(registrar: second, child: probe));
      expect(builds, 2);
    });

    testWidgets('register flows through the scope to the registrar', (tester) async {
      final registrar = _FakeRegistrar();
      final token = ElementRegistration(debugOwner: 'Text');
      await tester.pumpWidget(
        CompositionRegistrarScope(
          registrar: registrar,
          child: Builder(
            builder: (context) {
              final schedule = CompositionRegistrarScope.maybeOf(context)!.register(token);
              expect(schedule, isNull);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(registrar.registered, [same(token)]);
    });
  });
}
