// WI-29 (§14): the layout story is plain Flutter — Center/Column/Row/Padding/
// SizedBox/Stack/Positioned host .animate()d children inside a Video, timing
// flows via context, and no V* widget family exists in the public surface.

import 'dart:io';

import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/composition/box.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/keyframe.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/rendering/primitives/fade_box.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';

const _kTitle = Key('title');
const _kSubtitle = Key('subtitle');
const _kPositioned = Key('positioned');
const _kBar = Key('bar');

Animation _fade({Time delay = Time.zero}) => Animation.from(
  const Keyframe(opacity: 0),
  duration: const Time.frames(20),
  ease: Ease.linear,
  delay: delay,
);

/// The §14 story in one Video: nested plain-Flutter layout, every leaf
/// animated through `.animate()` alone.
Video _layoutStory() => Video(
  width: 320,
  height: 240,
  scenes: [
    Scene(
      duration: 60.frames,
      children: [
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Title',
                key: _kTitle,
                textDirection: TextDirection.ltr,
              ).animate([_fade()]),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.all(8),
                child: const Text(
                  'Subtitle',
                  key: _kSubtitle,
                  textDirection: TextDirection.ltr,
                ).animate([_fade(delay: const Time.frames(10))]),
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: TextDirection.ltr,
          children: [
            SizedBox(
              width: 60,
              height: 6,
              child: const Box(key: _kBar, color: Color(0xFFFFFFFF)).animate([_fade()]),
            ),
          ],
        ),
        Stack(
          textDirection: TextDirection.ltr,
          children: [
            Positioned(
              left: 10,
              top: 10,
              width: 30,
              height: 30,
              child: const ColoredBox(
                color: Color(0xFF3498DB),
                child: SizedBox.expand(key: _kPositioned),
              ).animate([_fade()]),
            ),
          ],
        ),
      ],
    ),
  ],
);

double _opacityOf(WidgetTester tester, Key key) => tester
    .widget<FadeBox>(
      find
          .ancestor(
            of: find.byKey(key, skipOffstage: false),
            matching: find.byType(FadeBox, skipOffstage: false),
          )
          .first,
    )
    .opacity;

void main() {
  group('the §14 layout story inside Video (WI-29)', () {
    testWidgets('timing reaches every leaf through plain Flutter layout', (tester) async {
      final controller = RenderController();
      await tester.pumpWidget(
        RenderModeContext(
          mode: RenderMode.capture,
          child: RenderControllerScope(controller: controller, child: _layoutStory()),
        ),
      );

      Future<void> seek(int frame) async {
        controller.seek(frame);
        await tester.pump();
      }

      // Frame 10: the un-delayed fades sit at 0.5; the delayed subtitle has
      // not started — context-resolved timing through Column/Padding/Row.
      await seek(10);
      expect(tester.takeException(), isNull);
      expect(_opacityOf(tester, _kTitle), closeTo(0.5, 1e-9));
      expect(_opacityOf(tester, _kSubtitle), 0.0);
      expect(_opacityOf(tester, _kBar), closeTo(0.5, 1e-9));
      // Frame 20: the subtitle is half-way through its delayed span.
      await seek(20);
      expect(_opacityOf(tester, _kTitle), 1.0);
      expect(_opacityOf(tester, _kSubtitle), closeTo(0.5, 1e-9));
    });

    testWidgets('a Positioned child animates without ParentData errors', (tester) async {
      final controller = RenderController();
      await tester.pumpWidget(
        RenderModeContext(
          mode: RenderMode.capture,
          child: RenderControllerScope(controller: controller, child: _layoutStory()),
        ),
      );
      controller.seek(10);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(_opacityOf(tester, _kPositioned), closeTo(0.5, 1e-9));
      // Positioned geometry survives the MotionTarget wrapper inside it; the
      // expanding scene Stack puts the inner Stack's origin at (0, 0).
      expect(tester.getSize(find.byKey(_kPositioned)), const Size(30, 30));
      expect(tester.getTopLeft(find.byKey(_kPositioned)), const Offset(10, 10));
    });
  });

  group('the public surface (WI-29 guardrail)', () {
    test('the barrel exports no V*-family layout widgets', () {
      final barrel = File('lib/fluvie.dart').readAsStringSync();
      final exports = RegExp(
        "^export '([^']+)';",
        multiLine: true,
      ).allMatches(barrel).map((match) => match.group(1)!);
      final declaration = RegExp(
        '^(?:abstract |base |final |interface |sealed |mixin )*'
        r'(?:class|enum|mixin|extension type|extension|typedef)\s+(\w+)',
        multiLine: true,
      );
      final names = <String>{
        for (final path in exports)
          ...declaration
              .allMatches(File('lib/$path').readAsStringSync())
              .map((match) => match.group(1)!),
      };
      // Sanity: the scan really sees the surface.
      expect(names, isNotEmpty);
      expect(names, contains('Animation'));
      // The Phase 7 surface reaches the barrel (the orchestrator pre-step):
      // Transition, SharedElement, and Camera resolve through it, and none of
      // them collides with a Flutter type the barrel re-exports.
      expect(names, containsAll(['Transition', 'SharedElement', 'Camera']));
      // The V* family (VStack, VRow, VText, ...) is gone for good (§14);
      // Video* names (lowercase second letter) are not part of that family.
      final vFamily = names.where((name) => RegExp('^V[A-Z]').hasMatch(name));
      expect(vFamily, isEmpty, reason: 'use plain Flutter layout widgets, not a V* family');
    });
  });
}
