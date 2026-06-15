// WI-27 (D14): Box sizes are always parent fractions — Size(0.5, 0.01) is
// half the parent's width by 1% of its height; null expands. Absolute sizing
// stays SizedBox per the §14 layout story.

import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/composition/box.dart';
import 'package:fluvie/src/composition/transition/shared_element.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/keyframe.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/timing/scene_scope.dart';
import 'package:fluvie/src/timing/video_scope.dart';

const _white = Color(0xFFFFFFFF);

/// Mounts [child] centered in a fixed 200×100 parent.
Widget _inParent(Widget child) => Center(
  child: SizedBox(width: 200, height: 100, child: Center(child: child)),
);

void main() {
  group('Box (D14, §14)', () {
    testWidgets('Size(0.5, 0.1) measures half the parent width, a tenth of its height', (
      tester,
    ) async {
      await tester.pumpWidget(
        _inParent(const Box(key: Key('box'), color: _white, size: Size(0.5, 0.1))),
      );
      final painted = tester.getSize(find.byType(ColoredBox));
      expect(painted, const Size(100, 10));
    });

    testWidgets('a null size expands to the whole parent', (tester) async {
      await tester.pumpWidget(_inParent(const Box(color: _white)));
      expect(tester.getSize(find.byType(ColoredBox)), const Size(200, 100));
    });

    testWidgets('decoration mounts a DecoratedBox carrying it', (tester) async {
      const decoration = BoxDecoration(color: Color(0xFF112233));
      await tester.pumpWidget(_inParent(const Box(size: Size(0.25, 0.5), decoration: decoration)));
      expect(tester.widget<DecoratedBox>(find.byType(DecoratedBox)).decoration, decoration);
      expect(tester.getSize(find.byType(DecoratedBox)), const Size(50, 50));
    });

    testWidgets('neither color nor decoration is a transparent spacer', (tester) async {
      await tester.pumpWidget(_inParent(const Box(key: Key('box'), size: Size(0.5, 0.5))));
      expect(find.byType(ColoredBox), findsNothing);
      expect(find.byType(DecoratedBox), findsNothing);
      expect(tester.getSize(find.byKey(const Key('box'))), const Size(100, 50));
    });

    test('color and decoration together assert', () {
      expect(
        () => Box(
          color: _white,
          decoration: const BoxDecoration(color: _white),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    testWidgets('shared: anchor wraps the box in a SharedElement (WI-11, D6)', (tester) async {
      final anchor = Anchor('hero');
      await tester.pumpWidget(
        _inParent(Box(color: _white, size: const Size(0.2, 0.2), shared: anchor)),
      );
      final shared = tester.widget<SharedElement>(find.byType(SharedElement));
      expect(shared.anchor, same(anchor));
      expect(
        find.descendant(of: find.byType(SharedElement), matching: find.byType(ColoredBox)),
        findsOneWidget,
      );
    });

    testWidgets('shared: null mounts no SharedElement (inert)', (tester) async {
      await tester.pumpWidget(_inParent(const Box(color: _white, size: Size(0.2, 0.2))));
      expect(find.byType(SharedElement), findsNothing);
    });

    testWidgets('the §14 grow-in rule compiles and animates scaleX 0 → 1', (tester) async {
      // Box(color: ..., size: Size(0.5, 0.01)).animate([Animation.from(const
      // Keyframe(scaleX: 0))]) — probed mid-span at scaleX 0.5.
      await tester.pumpWidget(
        RenderControllerScope(
          controller: RenderController(initialFrame: 10),
          child: VideoScope(
            fps: 30,
            duration: const Time.frames(60),
            child: SceneScope(
              duration: const Time.frames(60),
              child: _inParent(
                const Box(color: _white, size: Size(0.5, 0.01)).animate([
                  Animation.from(
                    const Keyframe(scaleX: 0),
                    duration: const Time.frames(20),
                    ease: Ease.linear,
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
      final matrix = tester.widget<Transform>(find.byType(Transform)).transform;
      expect(matrix.storage[0], closeTo(0.5, 1e-9));
      expect(tester.getSize(find.byType(ColoredBox)), const Size(100, 1));
    });
  });
}
