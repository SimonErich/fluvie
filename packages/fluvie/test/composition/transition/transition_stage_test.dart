import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/transition/transition_stage.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/transition.dart';
import 'package:fluvie/src/timing/placement/scene_offset_resolver.dart';

void main() {
  // Mixed 3-scene plan: overlap crossFade then a non-overlap crossFade.
  // starts [0, 50, 110], windows [0,60) [50,110) [110,170), total 170;
  // blend windows: boundary 0 = [50, 60), boundary 1 = [110, 130).
  final mixed = [
    Transition.crossFade(10.frames),
    Transition.crossFade(20.frames, overlap: false),
  ];
  final mixedOffsets = resolveSceneOffsets(
    fps: 30,
    durations: [60.frames, 60.frames, 60.frames],
    transitions: mixed,
  );

  List<SceneFrameState> at(int frame) =>
      stageAt(frame: frame, offsets: mixedOffsets, transitions: mixed);

  group('stageAt roles (D3 windows)', () {
    test('the resolved offsets pin the documented windows', () {
      expect(mixedOffsets.startFrames, [0, 50, 110]);
      expect(mixedOffsets.totalFrames, 170);
    });

    test('outside every blend window scenes are solo in their window, hidden elsewhere', () {
      expect(at(0).map((s) => s.role), [SceneRole.solo, SceneRole.hidden, SceneRole.hidden]);
      expect(at(49).map((s) => s.role), [SceneRole.solo, SceneRole.hidden, SceneRole.hidden]);
      expect(at(60).map((s) => s.role), [SceneRole.hidden, SceneRole.solo, SceneRole.hidden]);
      expect(at(109).map((s) => s.role), [SceneRole.hidden, SceneRole.solo, SceneRole.hidden]);
      expect(at(130).map((s) => s.role), [SceneRole.hidden, SceneRole.hidden, SceneRole.solo]);
      expect(at(169).map((s) => s.role), [SceneRole.hidden, SceneRole.hidden, SceneRole.solo]);
    });

    test('an overlap blend reports outgoing/incoming over the incoming head window', () {
      final states = at(50);
      expect(states.map((s) => s.role), [
        SceneRole.outgoing,
        SceneRole.incoming,
        SceneRole.hidden,
      ]);
      expect(states[0].boundary, 0);
      expect(states[1].boundary, 0);
    });

    test('a non-overlap blend reports the same pair one boundary later', () {
      final states = at(110);
      expect(states.map((s) => s.role), [
        SceneRole.hidden,
        SceneRole.outgoing,
        SceneRole.incoming,
      ]);
      expect(states[1].boundary, 1);
      expect(states[2].boundary, 1);
    });

    test('solo and hidden states carry no blend payload', () {
      for (final state in [...at(0), ...at(60)]) {
        expect(state.progress, 0);
        expect(state.holdFrame, isNull);
        expect(state.boundary, isNull);
      }
    });
  });

  group('stageAt progress: p in (0, 1] with the +1 convention (D3)', () {
    test('the first window frame is p = 1/F, never 0', () {
      expect(at(50)[0].progress, closeTo(0.1, 1e-9));
      expect(at(50)[1].progress, closeTo(0.1, 1e-9));
      expect(at(110)[1].progress, closeTo(1 / 20, 1e-9));
    });

    test('the last window frame is exactly p = 1', () {
      expect(at(59)[0].progress, 1.0);
      expect(at(59)[1].progress, 1.0);
      expect(at(129)[1].progress, 1.0);
      expect(at(129)[2].progress, 1.0);
    });

    test('the frame before the window is pure outgoing: no blend roles at all', () {
      expect(at(49).map((s) => s.role), [SceneRole.solo, SceneRole.hidden, SceneRole.hidden]);
    });
  });

  group('stageAt holdFrame (D10)', () {
    test('is null for an overlap boundary: the outgoing is still live', () {
      expect(at(55)[0].holdFrame, isNull);
    });

    test('is start[i+1] - 1 for a non-overlap boundary: the outgoing holds its final frame', () {
      expect(at(110)[1].holdFrame, 109);
      expect(at(129)[1].holdFrame, 109);
    });

    test('the incoming never carries a holdFrame', () {
      expect(at(55)[1].holdFrame, isNull);
      expect(at(115)[2].holdFrame, isNull);
    });
  });

  group('stageAt boundaries', () {
    test('a cut boundary never produces a blend', () {
      final transitions = [
        const Transition.cut(),
        Transition.crossFade(20.frames, overlap: false),
      ];
      final offsets = resolveSceneOffsets(
        fps: 30,
        durations: [60.frames, 60.frames, 60.frames],
        transitions: transitions,
      );

      final cutFrame = stageAt(frame: 60, offsets: offsets, transitions: transitions);
      expect(cutFrame.map((s) => s.role), [
        SceneRole.hidden,
        SceneRole.solo,
        SceneRole.hidden,
      ]);
    });

    test('an empty transitions list (all-cut) reproduces the SceneGate windows', () {
      final offsets = resolveSceneOffsets(fps: 30, durations: [60.frames, 60.frames]);

      final before = stageAt(frame: 59, offsets: offsets, transitions: const []);
      final after = stageAt(frame: 60, offsets: offsets, transitions: const []);
      expect(before.map((s) => s.role), [SceneRole.solo, SceneRole.hidden]);
      expect(after.map((s) => s.role), [SceneRole.hidden, SceneRole.solo]);
    });

    test('adjacent boundaries in one scene: head and tail both report correctly', () {
      // Both boundaries overlap: starts [0, 50, 90]; scene 2's window is
      // [50, 110) with an incoming head [50, 60) and a live tail [90, 110).
      final transitions = [Transition.crossFade(10.frames), Transition.crossFade(20.frames)];
      final offsets = resolveSceneOffsets(
        fps: 30,
        durations: [60.frames, 60.frames, 60.frames],
        transitions: transitions,
      );
      expect(offsets.startFrames, [0, 50, 90]);

      List<SceneFrameState> staged(int frame) =>
          stageAt(frame: frame, offsets: offsets, transitions: transitions);
      expect(staged(55)[1].role, SceneRole.incoming);
      expect(staged(55)[1].boundary, 0);
      expect(staged(75)[1].role, SceneRole.solo);
      expect(staged(95)[1].role, SceneRole.outgoing);
      expect(staged(95)[1].boundary, 1);
      expect(staged(95)[1].holdFrame, isNull);
      expect(staged(95)[2].role, SceneRole.incoming);
      expect(staged(95)[2].progress, closeTo(0.3, 1e-9));
    });
  });

  group('SceneFrameState', () {
    test('is a value: equal fields compare equal, and twice-staged frames match', () {
      expect(at(55), at(55));
      expect(at(0), at(0));
      expect(at(115), at(115));
      // Equal scene-frame states hash alike, keying the frame cache honestly.
      expect(at(55).first.hashCode, at(55).first.hashCode);
    });

    test('toString names the role and the blend payload', () {
      expect(at(0)[0].toString(), contains('solo'));
      expect(at(110)[1].toString(), allOf(contains('outgoing'), contains('109')));
    });
  });
}
