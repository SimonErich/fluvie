// The §22 headline proof for Epic 9.2: rendering the same particle subtree
// twice yields byte-identical paint. Untagged (a pure render check, not a
// golden) so it runs in the normal suite on every platform.
import 'dart:typed_data' show ByteData;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/particles/particles.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/timing/scene_scope.dart';
import 'package:fluvie/src/timing/video_scope.dart';

const _black = Color(0xFF000000);
const _probeKey = Key('probe');

/// A particle field driven `during` the whole scene at linear progress, so the
/// field scrolls deterministically as the frame advances `0 → 1`.
Animation _hold(Particles spec) => Animation.custom(
  Animation.particles(spec).effect,
  phase: AnimationPhase.during,
  duration: const Time.frames(60),
  ease: Ease.linear,
);

/// Mounts [spec] over a black square under a frame clock at [frame], inside a
/// repaint boundary whose pixels read back exactly as a capture would.
Widget _subtree(Particles spec, {required int frame}) => Center(
  child: RepaintBoundary(
    key: _probeKey,
    child: SizedBox(
      width: 100,
      height: 100,
      child: RenderControllerScope(
        controller: RenderController(initialFrame: frame),
        child: VideoScope(
          fps: 30,
          duration: const Time.frames(60),
          child: SceneScope(
            duration: const Time.frames(60),
            child: const ColoredBox(color: _black).animate([_hold(spec)]),
          ),
        ),
      ),
    ),
  ),
);

Future<ByteData> _bytes(WidgetTester tester) async {
  final boundary = tester.renderObject(find.byKey(_probeKey)) as RenderRepaintBoundary;
  late final ByteData data;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    data = (await image.toByteData())!;
    image.dispose();
  });
  return data;
}

void main() {
  group('Particles determinism (WI-14, §22)', () {
    testWidgets('two renders of the same confetti subtree are byte-identical', (tester) async {
      const spec = Particles.confetti(seed: 'win', count: 30);
      await tester.pumpWidget(_subtree(spec, frame: 30));
      final first = await _bytes(tester);
      await tester.pumpWidget(_subtree(spec, frame: 30));
      final second = await _bytes(tester);
      expect(first.buffer.asUint8List(), second.buffer.asUint8List());
    });

    testWidgets('two renders of the same snow subtree are byte-identical', (tester) async {
      const spec = Particles.snow(seed: 'flurry', count: 40);
      await tester.pumpWidget(_subtree(spec, frame: 18));
      final first = await _bytes(tester);
      await tester.pumpWidget(_subtree(spec, frame: 18));
      final second = await _bytes(tester);
      expect(first.buffer.asUint8List(), second.buffer.asUint8List());
    });

    testWidgets('two renders of the same sparkle subtree are byte-identical', (tester) async {
      const spec = Particles.sparkle(seed: 'glint', count: 28);
      await tester.pumpWidget(_subtree(spec, frame: 30));
      final first = await _bytes(tester);
      await tester.pumpWidget(_subtree(spec, frame: 30));
      final second = await _bytes(tester);
      expect(first.buffer.asUint8List(), second.buffer.asUint8List());
    });

    testWidgets('the field actually advances between frames (it is not static)', (tester) async {
      const spec = Particles.confetti(seed: 'move', count: 30);
      await tester.pumpWidget(_subtree(spec, frame: 6));
      final early = await _bytes(tester);
      await tester.pumpWidget(_subtree(spec, frame: 42));
      final late_ = await _bytes(tester);
      expect(early.buffer.asUint8List(), isNot(late_.buffer.asUint8List()));
    });
  });
}
