import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/runtime/keyframe_scope.dart';
import 'package:fluvie/src/composition/transition/runtime/shared_element_registry.dart';
import 'package:fluvie/src/composition/transition/runtime/shared_element_scope.dart';
import 'package:fluvie/src/composition/transition/runtime/shared_element_slot.dart';
import 'package:fluvie/src/composition/transition/runtime/transition_phase_scope.dart';
import 'package:fluvie/src/composition/transition/shared_element.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/keyframe.dart';

/// A marker child whose State value survives only if its Element is reused.
final class _Probe extends StatefulWidget {
  const _Probe();

  @override
  State<_Probe> createState() => _ProbeState();
}

final class _ProbeState extends State<_Probe> {
  int value = 0;

  @override
  Widget build(BuildContext context) => const SizedBox(width: 8, height: 8);
}

Widget _underScope({
  required SharedElementRegistry registry,
  required int sceneIndex,
  required Anchor anchor,
  Keyframe? keyframe,
  TransitionPhase? phase,
  bool alwaysPhaseScope = false,
}) {
  Widget tree = SharedElement(anchor: anchor, child: const _Probe());
  if (keyframe != null) tree = KeyframeScope(keyframe: keyframe, child: tree);
  // The compositor always mounts the phase scope (decision D8): a value
  // change, never a tree-shape change. [alwaysPhaseScope] mirrors that even
  // when the window is inactive (phase == null).
  if (phase != null || alwaysPhaseScope) {
    tree = TransitionPhaseScope(phase: phase, child: tree);
  }
  return SharedElementScope(registry: registry, sceneIndex: sceneIndex, child: tree);
}

void main() {
  group('SharedElement registration', () {
    testWidgets('registers a slot with its scene index under the scope', (tester) async {
      final registry = SharedElementRegistry();
      final logo = Anchor('logo');
      await tester.pumpWidget(
        _underScope(registry: registry, sceneIndex: 2, anchor: logo),
      );
      // The slot's box is the SharedElementSlot's render box, recorded live.
      final pairless = registry.pairAtBoundary(1);
      expect(pairless, isNull); // only one slot so far
      // Register the matching slot to form a pair across boundary 1.
      await tester.pumpWidget(
        Column(
          textDirection: TextDirection.ltr,
          children: [
            _underScope(registry: registry, sceneIndex: 1, anchor: logo),
            _underScope(registry: registry, sceneIndex: 2, anchor: logo),
          ],
        ),
      );
      final pair = registry.pairAtBoundary(1);
      expect(pair, isNotNull);
      expect(pair!.source.box, isNotNull);
      expect(pair.target.box, isNotNull);
    });

    testWidgets('passes through unchanged without a scope (standalone)', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SharedElement(anchor: null, child: _Probe()),
        ),
      );
      expect(find.byType(_Probe), findsOneWidget);
      // No slot is mounted in the standalone path.
      expect(find.byType(SharedElementSlot), findsNothing);
    });

    testWidgets('unregisters on dispose', (tester) async {
      final registry = SharedElementRegistry();
      final logo = Anchor('logo');
      await tester.pumpWidget(
        Column(
          textDirection: TextDirection.ltr,
          children: [
            _underScope(registry: registry, sceneIndex: 0, anchor: logo),
            _underScope(registry: registry, sceneIndex: 1, anchor: logo),
          ],
        ),
      );
      expect(registry.pairAtBoundary(0), isNotNull);
      await tester.pumpWidget(const SizedBox());
      expect(registry.pairAtBoundary(0), isNull);
    });
  });

  group('SharedElement opacity tracking', () {
    testWidgets('the slot handle opacity follows an enclosing KeyframeScope', (tester) async {
      final registry = SharedElementRegistry();
      final logo = Anchor('logo');
      await tester.pumpWidget(
        Column(
          textDirection: TextDirection.ltr,
          children: [
            _underScope(registry: registry, sceneIndex: 0, anchor: logo),
            _underScope(
              registry: registry,
              sceneIndex: 1,
              anchor: logo,
              keyframe: const Keyframe(opacity: 0.4),
            ),
          ],
        ),
      );
      final pair = registry.pairAtBoundary(0)!;
      expect(pair.source.opacity, 1.0); // natural, no keyframe
      expect(pair.target.opacity, 0.4); // tracks the keyframe
    });
  });

  group('SharedElementSlot suppression (D8)', () {
    testWidgets('suppresses paint only with an active window and a complete pair', (tester) async {
      final registry = SharedElementRegistry();
      final logo = Anchor('logo');
      // A complete pair across boundary 0; window active on boundary 0.
      await tester.pumpWidget(
        Column(
          textDirection: TextDirection.ltr,
          children: [
            _underScope(
              registry: registry,
              sceneIndex: 0,
              anchor: logo,
              phase: const TransitionPhase(boundary: 0, progress: 0.5),
            ),
            _underScope(
              registry: registry,
              sceneIndex: 1,
              anchor: logo,
              phase: const TransitionPhase(boundary: 0, progress: 0.5),
            ),
          ],
        ),
      );
      final slots = tester
          .renderObjectList<RenderSharedElementSlot>(find.byType(SharedElementSlot))
          .toList();
      expect(slots, hasLength(2));
      expect(slots.every((s) => s.suppress), isTrue);
    });

    testWidgets('does not suppress without an active window', (tester) async {
      final registry = SharedElementRegistry();
      final logo = Anchor('logo');
      await tester.pumpWidget(
        Column(
          textDirection: TextDirection.ltr,
          children: [
            _underScope(registry: registry, sceneIndex: 0, anchor: logo),
            _underScope(registry: registry, sceneIndex: 1, anchor: logo),
          ],
        ),
      );
      final slots = tester
          .renderObjectList<RenderSharedElementSlot>(find.byType(SharedElementSlot))
          .toList();
      expect(slots.every((s) => !s.suppress), isTrue);
    });

    testWidgets('suppression toggle never changes the child Element identity', (tester) async {
      final registry = SharedElementRegistry();
      final logo = Anchor('logo');
      Widget build(TransitionPhase? phase) => Column(
        textDirection: TextDirection.ltr,
        children: [
          _underScope(
            registry: registry,
            sceneIndex: 0,
            anchor: logo,
            phase: phase,
            alwaysPhaseScope: true,
          ),
          _underScope(
            registry: registry,
            sceneIndex: 1,
            anchor: logo,
            phase: phase,
            alwaysPhaseScope: true,
          ),
        ],
      );
      await tester.pumpWidget(build(null));
      final probe = find.byType(_Probe).first;
      tester.state<_ProbeState>(probe).value = 7;
      final before = tester.element(probe);

      await tester.pumpWidget(build(const TransitionPhase(boundary: 0, progress: 0.5)));
      expect(identical(tester.element(find.byType(_Probe).first), before), isTrue);
      expect(tester.state<_ProbeState>(find.byType(_Probe).first).value, 7);
    });
  });
}
