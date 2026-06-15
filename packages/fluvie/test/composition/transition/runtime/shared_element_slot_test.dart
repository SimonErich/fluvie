import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/transition/runtime/shared_element_registry.dart';
import 'package:fluvie/src/composition/transition/runtime/shared_element_slot.dart';
import 'package:fluvie/src/composition/transition/runtime/transition_phase_scope.dart';
import 'package:fluvie/src/core/anchor.dart';

/// Mounts one slot and returns its live render object.
Future<RenderSharedElementSlot> _mountSlot(
  WidgetTester tester, {
  required SharedSlotHandle handle,
  required SharedElementRegistry registry,
  required int sceneIndex,
  required TransitionPhase? phase,
}) async {
  await tester.pumpWidget(
    SharedElementSlot(
      handle: handle,
      registry: registry,
      sceneIndex: sceneIndex,
      phase: phase,
      child: const SizedBox(width: 10, height: 10),
    ),
  );
  return tester.renderObject<RenderSharedElementSlot>(find.byType(SharedElementSlot));
}

SharedSlotHandle _handle(Anchor anchor, int scene) =>
    SharedSlotHandle(anchor: anchor, sceneIndex: scene, child: const SizedBox());

void main() {
  group('RenderSharedElementSlot reactive setters (WI-24, D8)', () {
    testWidgets('attach records the slot box on its handle', (tester) async {
      final anchor = Anchor('logo');
      final handle = _handle(anchor, 0);
      final render = await _mountSlot(
        tester,
        handle: handle,
        registry: SharedElementRegistry(),
        sceneIndex: 0,
        phase: null,
      );
      // attach() ran during mount, publishing the box pointer.
      expect(handle.box, same(render));
    });

    testWidgets('the handle setter moves the box pointer to the new handle', (tester) async {
      final anchor = Anchor('logo');
      final first = _handle(anchor, 0);
      final registry = SharedElementRegistry();
      final render = await _mountSlot(
        tester,
        handle: first,
        registry: registry,
        sceneIndex: 0,
        phase: null,
      );
      expect(first.box, same(render));

      final second = _handle(anchor, 0);
      await tester.pumpWidget(
        SharedElementSlot(
          handle: second,
          registry: registry,
          sceneIndex: 0,
          phase: null,
          child: const SizedBox(width: 10, height: 10),
        ),
      );
      // The old handle is released and the new one now owns the box.
      expect(first.box, isNull);
      expect(second.box, same(render));
    });

    testWidgets('reassigning the identical handle is a no-op (early return)', (tester) async {
      final anchor = Anchor('logo');
      final handle = _handle(anchor, 0);
      final render = await _mountSlot(
        tester,
        handle: handle,
        registry: SharedElementRegistry(),
        sceneIndex: 0,
        phase: null,
      );
      render.handle = handle; // identical → returns before any pointer churn
      expect(handle.box, same(render));
    });

    testWidgets('the registry setter swaps the registry and a same-value set is inert', (
      tester,
    ) async {
      final anchor = Anchor('logo');
      final registry = SharedElementRegistry();
      final render = await _mountSlot(
        tester,
        handle: _handle(anchor, 0),
        registry: registry,
        sceneIndex: 0,
        phase: null,
      );
      final other = SharedElementRegistry();
      render.registry = other;
      expect(render.registry, same(other));
      render.registry = other; // identical → early return, registry unchanged
      expect(render.registry, same(other));
    });

    testWidgets('the sceneIndex setter updates and a same-value set is inert', (tester) async {
      final anchor = Anchor('logo');
      final render = await _mountSlot(
        tester,
        handle: _handle(anchor, 0),
        registry: SharedElementRegistry(),
        sceneIndex: 0,
        phase: null,
      );
      render.sceneIndex = 1;
      expect(render.sceneIndex, 1);
      render.sceneIndex = 1; // equal → early return
      expect(render.sceneIndex, 1);
    });

    testWidgets('the phase setter updates and a same-value set is inert', (tester) async {
      final anchor = Anchor('logo');
      final render = await _mountSlot(
        tester,
        handle: _handle(anchor, 0),
        registry: SharedElementRegistry(),
        sceneIndex: 0,
        phase: null,
      );
      const next = TransitionPhase(boundary: 0, progress: 0.5);
      render.phase = next;
      expect(render.phase, next);
      render.phase = const TransitionPhase(
        boundary: 0,
        progress: 0.5,
      ); // equal value → early return
      expect(render.phase, next);
    });

    testWidgets('suppress is true only with an active window and a complete pair', (tester) async {
      final anchor = Anchor('logo');
      final registry = SharedElementRegistry()
        ..register(SharedSlotHandle(anchor: anchor, sceneIndex: 0, child: const SizedBox()))
        ..register(SharedSlotHandle(anchor: anchor, sceneIndex: 1, child: const SizedBox()));
      final source = _handle(anchor, 0);
      registry.register(source);
      final render = await _mountSlot(
        tester,
        handle: source,
        registry: registry,
        sceneIndex: 0,
        phase: const TransitionPhase(boundary: 0, progress: 0.5),
      );
      // Window active on boundary 0 and this scene-0 slot's anchor pairs across it.
      expect(render.suppress, isTrue);

      render.phase = null;
      expect(render.suppress, isFalse); // no window → never suppress
    });

    testWidgets('a slot outside the window boundary never suppresses', (tester) async {
      final anchor = Anchor('logo');
      final registry = SharedElementRegistry()
        ..register(SharedSlotHandle(anchor: anchor, sceneIndex: 0, child: const SizedBox()))
        ..register(SharedSlotHandle(anchor: anchor, sceneIndex: 1, child: const SizedBox()));
      final render = await _mountSlot(
        tester,
        handle: _handle(anchor, 5),
        registry: registry,
        sceneIndex: 5,
        phase: const TransitionPhase(boundary: 0, progress: 0.5),
      );
      expect(render.suppress, isFalse);
    });

    testWidgets('the live handle getter returns the current handle', (tester) async {
      final anchor = Anchor('logo');
      final handle = _handle(anchor, 0);
      final render = await _mountSlot(
        tester,
        handle: handle,
        registry: SharedElementRegistry(),
        sceneIndex: 0,
        phase: null,
      );
      expect(render.handle, same(handle));
    });
  });

  group('TransitionPhase value semantics', () {
    test('equal phases share a hashCode and a diagnostic toString', () {
      const a = TransitionPhase(boundary: 1, progress: 0.25);
      const b = TransitionPhase(boundary: 1, progress: 0.25);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.toString(), 'TransitionPhase(boundary: 1, progress: 0.25)');
    });

    test('a differing boundary or progress breaks equality', () {
      const base = TransitionPhase(boundary: 1, progress: 0.25);
      expect(base, isNot(const TransitionPhase(boundary: 2, progress: 0.25)));
      expect(base, isNot(const TransitionPhase(boundary: 1, progress: 0.5)));
    });
  });
}
