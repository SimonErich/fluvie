// WI-23 (the orchestrator barrel pre-step): the Phase 7 surface resolves
// through the single public barrel and nothing else. This file imports only
// `package:fluvie/fluvie.dart`; referencing Transition, SharedElement, and
// Camera here at all is the proof they are exported and do not collide with a
// Flutter type the barrel re-exports.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

void main() {
  group('the Phase 7 public surface (barrel hygiene)', () {
    test('Transition factories resolve through the barrel', () {
      const cut = Transition.cut();
      final crossFade = Transition.crossFade(0.5.seconds, overlap: false);
      expect(cut.kind, TransitionKind.cut);
      expect(crossFade.kind, TransitionKind.crossFade);
      expect(crossFade.overlap, isFalse);
    });

    test('Camera factories resolve through the barrel', () {
      const still = Camera.still();
      const push = Camera.push(zoom: 1.25);
      expect(still.poseAt(1).scale, 1.0);
      expect(push.poseAt(1).scale, 1.25);
    });

    test('SharedElement is a Widget reachable through the barrel', () {
      final element = SharedElement(anchor: Anchor('logo'), child: const SizedBox());
      expect(element, isA<Widget>());
      expect(element.anchor, isNotNull);
    });
  });
}
