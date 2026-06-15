import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/effect_kind.dart';
import 'package:fluvie/src/animation/effects/parallax_effect.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';

const _probeKey = Key('probe');
const _child = SizedBox(key: _probeKey, width: 10, height: 10);

/// Mounts [built] under a frame clock at [frame] inside a 60-frame scene scope.
Widget _host(Widget built, {required int frame, int sceneFrames = 60}) => Directionality(
  textDirection: TextDirection.ltr,
  child: FrameProvider(
    frame: frame,
    child: TimeScopeProvider(
      scope: TimeScopeData(fps: 30, startFrame: 0, durationFrames: sceneFrames),
      child: Center(child: built),
    ),
  ),
);

/// The FractionalTranslation the parallax mounted, read back from the tree.
FractionalTranslation _translation(WidgetTester tester) =>
    tester.widget<FractionalTranslation>(find.byType(FractionalTranslation));

void main() {
  group('ParallaxEffect — classification (D8)', () {
    test('classifies as a transform-class effect, not a pixel effect', () {
      const effect = ParallaxEffect();
      expect(effectKindOf(effect), EffectKind.transform);
      expect(effect, isNot(isA<PixelAnimationEffect>()));
    });

    test('carries its depth and defaults to 0.2', () {
      expect(const ParallaxEffect().depth, 0.2);
      expect(const ParallaxEffect(depth: 0.5).depth, 0.5);
    });
  });

  group('ParallaxEffect — offset from scene progress', () {
    testWidgets('offset is depth times scene progress at the current frame', (tester) async {
      // Halfway through a 60-frame scene (frame 30), progress is 0.5.
      await tester.pumpWidget(_host(const ParallaxEffect(depth: 0.4).build(_child, 0), frame: 30));
      expect(_translation(tester).translation.dy, closeTo(0.4 * 0.5, 1e-9));
    });

    testWidgets('a deeper depth translates proportionally more at the same frame', (tester) async {
      await tester.pumpWidget(_host(const ParallaxEffect(depth: 0.15).build(_child, 0), frame: 45));
      final shallow = _translation(tester).translation.dy;
      await tester.pumpWidget(_host(const ParallaxEffect(depth: 0.45).build(_child, 0), frame: 45));
      final deep = _translation(tester).translation.dy;
      expect(deep, closeTo(shallow * 3, 1e-9), reason: '0.45 depth is 3x the 0.15 depth');
    });

    testWidgets('progress 0 at the scene start leaves the child unmoved', (tester) async {
      await tester.pumpWidget(_host(const ParallaxEffect(depth: 0.5).build(_child, 0), frame: 0));
      expect(_translation(tester).translation.dy, 0);
    });
  });

  group('ParallaxEffect — determinism (§22)', () {
    testWidgets('two builds at the same frame mount the identical offset', (tester) async {
      await tester.pumpWidget(_host(const ParallaxEffect(depth: 0.3).build(_child, 0), frame: 21));
      final first = _translation(tester).translation;
      await tester.pumpWidget(_host(const ParallaxEffect(depth: 0.3).build(_child, 0), frame: 21));
      final second = _translation(tester).translation;
      expect(first, second);
    });
  });

  group('ParallaxEffect — frame clock', () {
    testWidgets('reads the scene window so progress runs 0..1 across it', (tester) async {
      await tester.pumpWidget(_host(const ParallaxEffect(depth: 1).build(_child, 0), frame: 60));
      // At the last frame index of a 60-frame scene, progress reaches 1.
      expect(_translation(tester).translation.dy, closeTo(1, 1e-9));
    });
  });
}
