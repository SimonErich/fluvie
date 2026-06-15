import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/runtime/transition_compositor.dart';
import 'package:fluvie/src/composition/transition/transition_stage.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/transition.dart';
import 'package:fluvie/src/rendering/primitives/fade_box.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/timing/placement/scene_offset_resolver.dart';

/// Records every frame its build sees — the animated-child stand-in.
final class _FrameProbe extends StatelessWidget {
  const _FrameProbe(this.frames);

  final List<int> frames;

  @override
  Widget build(BuildContext context) {
    frames.add(FrameProvider.of(context).frame);
    return const SizedBox.expand();
  }
}

final class _StateProbe extends StatefulWidget {
  const _StateProbe();

  @override
  State<_StateProbe> createState() => _StateProbeState();
}

final class _StateProbeState extends State<_StateProbe> {
  int value = 0;

  @override
  Widget build(BuildContext context) => const SizedBox(width: 5, height: 5);
}

void main() {
  // Two 60-frame scenes at 30 fps throughout.
  final durations = [60.frames, 60.frames];

  Widget harness({
    required RenderController controller,
    required List<Transition?> transitions,
    required List<Widget> shells,
  }) {
    final offsets = resolveSceneOffsets(fps: 30, durations: durations, transitions: transitions);
    return Center(
      child: SizedBox(
        width: 100,
        height: 100,
        child: RepaintBoundary(
          child: RenderControllerScope(
            controller: controller,
            child: TransitionCompositor(
              offsets: offsets,
              transitions: transitions,
              sceneShells: shells,
            ),
          ),
        ),
      ),
    );
  }

  Future<Uint8List> capture(WidgetTester tester) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).first,
    );
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData();
      return data!.buffer.asUint8List();
    });
    return bytes!;
  }

  group('TransitionCompositor role dispatch (D7)', () {
    final overlap = [Transition.crossFade(20.frames)]; // starts [0, 40], window [40, 60)

    testWidgets('outside the blend window scenes are Offstage-gated like SceneGate', (
      tester,
    ) async {
      final controller = RenderController();
      await tester.pumpWidget(
        harness(
          controller: controller,
          transitions: overlap,
          shells: const [SizedBox(), SizedBox()],
        ),
      );

      List<bool> flags() => [
        for (final offstage in tester.widgetList<Offstage>(
          find.byType(Offstage, skipOffstage: false),
        ))
          offstage.offstage,
      ];
      expect(flags(), [false, true]); // scene 1 solo, scene 2 hidden

      controller.seek(60);
      await tester.pump();
      expect(flags(), [true, false]); // scene 1 hidden, scene 2 solo
    });

    testWidgets('inside the window the pair is strategy-blended, matching stageAt', (
      tester,
    ) async {
      final controller = RenderController(initialFrame: 45);
      final offsets = resolveSceneOffsets(fps: 30, durations: durations, transitions: overlap);
      await tester.pumpWidget(
        harness(
          controller: controller,
          transitions: overlap,
          shells: const [SizedBox(), SizedBox()],
        ),
      );

      final state = stageAt(frame: 45, offsets: offsets, transitions: overlap)[1];
      expect(state.role, SceneRole.incoming);
      expect(find.byType(Offstage), findsNothing); // both scenes live
      final fade = tester.widget<FadeBox>(find.byType(FadeBox));
      expect(fade.opacity, state.progress); // linear ease: te == p == 0.3
    });

    testWidgets('a hidden scene keeps its state alive (the SceneGate probe)', (tester) async {
      final controller = RenderController();
      await tester.pumpWidget(
        harness(
          controller: controller,
          transitions: overlap,
          shells: const [SizedBox(), _StateProbe()],
        ),
      );
      final hiddenProbe = find.byType(_StateProbe, skipOffstage: false);
      tester.state<_StateProbeState>(hiddenProbe).value = 42;

      controller.seek(70); // scene 2 solo, scene 1 hidden
      await tester.pump();
      expect(tester.state<_StateProbeState>(hiddenProbe).value, 42);

      controller.seek(0);
      await tester.pump();
      expect(tester.state<_StateProbeState>(hiddenProbe).value, 42);
    });

    testWidgets('a global-keyed shell keeps its state across role changes (the 7.2 contract)', (
      tester,
    ) async {
      final key = GlobalKey();
      final controller = RenderController();
      await tester.pumpWidget(
        harness(
          controller: controller,
          transitions: overlap,
          shells: [
            KeyedSubtree(key: key, child: const _StateProbe()),
            const SizedBox(),
          ],
        ),
      );
      final probe = find.byType(_StateProbe, skipOffstage: false);
      tester.state<_StateProbeState>(probe).value = 42;

      controller.seek(45); // solo → outgoing: the strategy re-wraps the shell
      await tester.pump();
      expect(tester.state<_StateProbeState>(probe).value, 42);

      controller.seek(60); // outgoing → hidden
      await tester.pump();
      expect(tester.state<_StateProbeState>(probe).value, 42);
    });
  });

  group('TransitionCompositor non-overlap hold (D10)', () {
    final held = [Transition.crossFade(20.frames, overlap: false)]; // window [60, 80)

    testWidgets('the outgoing is frozen at its final frame while the incoming animates', (
      tester,
    ) async {
      final outgoingFrames = <int>[];
      final incomingFrames = <int>[];
      final controller = RenderController(initialFrame: 65);
      await tester.pumpWidget(
        harness(
          controller: controller,
          transitions: held,
          shells: [_FrameProbe(outgoingFrames), _FrameProbe(incomingFrames)],
        ),
      );

      expect(outgoingFrames.last, 59); // held at start[1] - 1
      expect(incomingFrames.last, 65); // live

      controller.seek(70);
      await tester.pump();
      expect(outgoingFrames.last, 59); // FrameClamp never rebuilds the held subtree
      expect(incomingFrames.last, 70);
    });
  });

  group('TransitionCompositor continuity (D3)', () {
    final overlap = [Transition.crossFade(20.frames)]; // window [40, 60)
    const shells = [
      ColoredBox(color: Color(0xFFFF0000)),
      ColoredBox(color: Color(0xFF0000FF)),
    ];

    testWidgets('the last blend frame (p = 1) is pixel-equal to the incoming solo', (
      tester,
    ) async {
      final controller = RenderController(initialFrame: 59);
      await tester.pumpWidget(
        harness(controller: controller, transitions: overlap, shells: shells),
      );
      final lastBlend = await capture(tester);

      controller.seek(60);
      await tester.pump();
      final firstSolo = await capture(tester);

      expect(lastBlend, firstSolo);
    });

    testWidgets('seeking away and back reproduces a blend frame byte-for-byte', (tester) async {
      final controller = RenderController(initialFrame: 49);
      await tester.pumpWidget(
        harness(controller: controller, transitions: overlap, shells: shells),
      );
      final first = await capture(tester);

      controller.seek(0);
      await tester.pump();
      controller.seek(49);
      await tester.pump();
      final second = await capture(tester);

      expect(first, second);
    });
  });

  group('TransitionCompositor guards', () {
    testWidgets('throws the FrameProvider error without a RenderControllerScope', (tester) async {
      final offsets = resolveSceneOffsets(fps: 30, durations: durations);
      await tester.pumpWidget(
        TransitionCompositor(
          offsets: offsets,
          transitions: const [],
          sceneShells: const [SizedBox(), SizedBox()],
        ),
      );

      expect(tester.takeException(), isA<FluvieTimingError>());
    });
  });
}
