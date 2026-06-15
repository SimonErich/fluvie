import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/animation/runtime/animation_pipeline.dart';
import 'package:fluvie/src/animation/runtime/gradient_shift_scope.dart';
import 'package:fluvie/src/composition/background/background.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/timing/resolver/trigger_resolver.dart';
import 'package:fluvie/src/timing/scene_scope.dart';
import 'package:fluvie/src/timing/schedule/element_schedule.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';
import 'package:fluvie/src/timing/video_scope.dart';

const _red = Color(0xFFFF0000);
const _green = Color(0xFF00FF00);
const _blue = Color(0xFF0000FF);
const _white = Color(0xFFFFFFFF);

/// Renders [background] inside a 160×284 boundary and returns its raw pixels.
Future<Uint8List> _pixelsOf(WidgetTester tester, Background background) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    Center(
      child: RepaintBoundary(
        key: key,
        child: SizedBox(width: 160, height: 284, child: background),
      ),
    ),
  );
  late final Uint8List bytes;
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final data = await image.toByteData();
    bytes = data!.buffer.asUint8List();
  });
  // Tear down so the next capture is a fresh, independent mount.
  await tester.pumpWidget(const SizedBox.shrink());
  return bytes;
}

LinearGradient _paintedLinear(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(of: find.byType(Background), matching: find.byType(DecoratedBox)),
  );
  return (box.decoration as BoxDecoration).gradient! as LinearGradient;
}

RadialGradient _paintedRadial(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(of: find.byType(Background), matching: find.byType(DecoratedBox)),
  );
  return (box.decoration as BoxDecoration).gradient! as RadialGradient;
}

void main() {
  group('Background.color (WI-22, D13 — the KeyframeScope seam closes)', () {
    testWidgets('paints its own color when no keyframe is published', (tester) async {
      await tester.pumpWidget(Background.color(_red));
      final box = tester.widget<ColoredBox>(
        find.descendant(of: find.byType(Background), matching: find.byType(ColoredBox)),
      );
      expect(box.color, _red);
    });

    testWidgets('paints the composed keyframe color through the real pipeline', (tester) async {
      // Animation.color's lerped color was pure data in Phase 5 (D9); the
      // fill background is the first lib consumer that actually paints it.
      await tester.pumpWidget(
        buildAnimatedFrame(
          child: Background.color(_red),
          animations: [Animation.color(to: _blue)],
          schedule: const ElementSchedule(
            window: ResolvedSpan(0, 60),
            spans: [ResolvedSpan(0, 20)],
            defaults: Defaults(duration: Time.frames(20), ease: Ease.linear),
          ),
          elementScope: const TimeScopeData(fps: 30, startFrame: 0, durationFrames: 60),
          frame: 10,
        ),
      );
      final box = tester.widget<ColoredBox>(
        find.descendant(of: find.byType(Background), matching: find.byType(ColoredBox)),
      );
      expect(box.color, Color.lerp(null, _blue, 0.5));
    });
  });

  group('Background.gradient (WI-22, D10)', () {
    testWidgets('paints its colors with the default top-left → bottom-right axis', (tester) async {
      await tester.pumpWidget(Background.gradient(const [_red, _green]));
      final gradient = _paintedLinear(tester);
      expect(gradient.colors, const [_red, _green]);
      expect(gradient.begin, Alignment.topLeft);
      expect(gradient.end, Alignment.bottomRight);
    });

    testWidgets('carries a custom begin/end verbatim', (tester) async {
      await tester.pumpWidget(
        Background.gradient(
          const [_red, _green],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ),
      );
      final gradient = _paintedLinear(tester);
      expect(gradient.begin, Alignment.bottomLeft);
      expect(gradient.end, Alignment.topRight);
    });

    for (final progress in const [0.0, 0.5, 1.0]) {
      testWidgets('lerps pairwise toward the scope colors at progress $progress', (tester) async {
        await tester.pumpWidget(
          GradientShiftScope(
            progress: progress,
            colors: const [_blue, _green],
            child: Background.gradient(const [_red, _green]),
          ),
        );
        expect(_paintedLinear(tester).colors, [
          Color.lerp(_red, _blue, progress),
          Color.lerp(_green, _green, progress),
        ]);
      });
    }

    testWidgets('asserts when the shift colors do not pair up with the base', (tester) async {
      await tester.pumpWidget(
        GradientShiftScope(
          progress: 0.5,
          colors: const [_blue],
          child: Background.gradient(const [_red, _green]),
        ),
      );
      expect(tester.takeException(), isA<AssertionError>());
    });
  });

  group('Background.radial (WI-22, D10)', () {
    testWidgets('paints its colors as a radial gradient', (tester) async {
      await tester.pumpWidget(Background.radial(const [_white, _blue]));
      expect(_paintedRadial(tester).colors, const [_white, _blue]);
    });

    testWidgets('lerps pairwise toward the scope colors', (tester) async {
      await tester.pumpWidget(
        GradientShiftScope(
          progress: 0.5,
          colors: const [_blue, _red],
          child: Background.radial(const [_white, _blue]),
        ),
      );
      expect(_paintedRadial(tester).colors, [
        Color.lerp(_white, _blue, 0.5),
        Color.lerp(_blue, _red, 0.5),
      ]);
    });
  });

  group('Background.noise / Background.vhs (WI-22, D12 — seeded painters)', () {
    testWidgets('noise renders byte-identical pixels across two fresh mounts', (tester) async {
      final first = await _pixelsOf(tester, Background.noise());
      final second = await _pixelsOf(tester, Background.noise());
      expect(listEquals(first, second), isTrue);
    });

    testWidgets('the noise scale changes the texture', (tester) async {
      final fine = await _pixelsOf(tester, Background.noise());
      final coarse = await _pixelsOf(tester, Background.noise(scale: 4));
      expect(listEquals(fine, coarse), isFalse);
    });

    testWidgets('vhs renders byte-identical pixels across two fresh mounts', (tester) async {
      final first = await _pixelsOf(tester, const Background.vhs());
      final second = await _pixelsOf(tester, const Background.vhs());
      expect(listEquals(first, second), isTrue);
    });
  });

  group('Background layout (WI-22, D6 — self-expanding)', () {
    testWidgets('expands to fill its parent', (tester) async {
      await tester.pumpWidget(
        Center(child: SizedBox(width: 200, height: 100, child: Background.color(_red))),
      );
      expect(tester.getSize(find.byType(Background)), const Size(200, 100));
    });

    testWidgets('animates inside a Stack without ParentData errors', (tester) async {
      await tester.pumpWidget(
        RenderControllerScope(
          controller: RenderController(),
          child: VideoScope(
            fps: 30,
            duration: const Time.frames(60),
            child: SceneScope(
              duration: const Time.frames(60),
              child: Stack(
                alignment: Alignment.topLeft,
                children: [
                  Background.gradient(const [_red, _green]).animate([
                    Animation.gradientShift(
                      to: const [_blue, _green],
                      duration: const Time.frames(20),
                      ease: Ease.linear,
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(Background)), const Size(800, 600));
      // Frame 0: the shift is mounted (progress 0), the base colors hold.
      expect(_paintedLinear(tester).colors, [
        Color.lerp(_red, _blue, 0),
        Color.lerp(_green, _green, 0),
      ]);
    });
  });
}
