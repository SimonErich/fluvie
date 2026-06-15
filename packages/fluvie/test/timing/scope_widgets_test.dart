import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/timing/scene_scope.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';
import 'package:fluvie/src/timing/video_scope.dart';

/// A leaf that reports the nearest scope to [onScope].
Widget _probe(void Function(TimeScopeData scope) onScope) => Builder(
  builder: (context) {
    onScope(TimeScopeProvider.of(context));
    return const SizedBox.shrink();
  },
);

void main() {
  group('TimeScopeProvider', () {
    testWidgets('of returns the nearest scope', (tester) async {
      const outer = TimeScopeData(fps: 30, startFrame: 0, durationFrames: 600);
      final inner = outer.child(startFrame: 60, durationFrames: 300);
      late TimeScopeData seen;
      await tester.pumpWidget(
        TimeScopeProvider(
          scope: outer,
          child: TimeScopeProvider(scope: inner, child: _probe((scope) => seen = scope)),
        ),
      );
      expect(seen, inner);
    });

    testWidgets('maybeOf returns null without a provider above', (tester) async {
      TimeScopeData? seen;
      var probed = false;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            seen = TimeScopeProvider.maybeOf(context);
            probed = true;
            return const SizedBox.shrink();
          },
        ),
      );
      expect(probed, isTrue);
      expect(seen, isNull);
    });

    testWidgets('of throws FluvieTimingError without a provider above', (tester) async {
      await tester.pumpWidget(_probe((_) {}));
      expect(tester.takeException(), isA<FluvieTimingError>());
    });

    test('updateShouldNotify fires only when the scope changes', () {
      const child = SizedBox.shrink();
      const old = TimeScopeProvider(
        scope: TimeScopeData(fps: 30, startFrame: 0, durationFrames: 300),
        child: child,
      );
      const equal = TimeScopeProvider(
        scope: TimeScopeData(fps: 30, startFrame: 0, durationFrames: 300),
        child: child,
      );
      const longer = TimeScopeProvider(
        scope: TimeScopeData(fps: 30, startFrame: 0, durationFrames: 600),
        child: child,
      );
      expect(equal.updateShouldNotify(old), isFalse);
      expect(longer.updateShouldNotify(old), isTrue);
    });
  });

  group('VideoScope', () {
    testWidgets('injects the root scope: fps, frame 0, resolved duration', (tester) async {
      late TimeScopeData seen;
      await tester.pumpWidget(
        VideoScope(fps: 30, duration: 10.seconds, child: _probe((scope) => seen = scope)),
      );
      expect(seen, const TimeScopeData(fps: 30, startFrame: 0, durationFrames: 300));
    });

    testWidgets('rejects a relative duration: circular at the root (D13)', (tester) async {
      await tester.pumpWidget(
        VideoScope(fps: 30, duration: 0.5.relative, child: const SizedBox.shrink()),
      );
      expect(tester.takeException(), isA<FluvieTimingError>());

      // A composite hiding a relative part is caught the same way.
      await tester.pumpWidget(
        VideoScope(fps: 30, duration: 2.seconds + 0.1.relative, child: const SizedBox.shrink()),
      );
      expect(tester.takeException(), isA<FluvieTimingError>());
    });
  });

  group('SceneScope', () {
    testWidgets('nests with resolved duration and a running start', (tester) async {
      late TimeScopeData seen;
      await tester.pumpWidget(
        VideoScope(
          fps: 30,
          duration: 20.seconds,
          child: SceneScope(
            duration: 10.seconds,
            start: 5.seconds,
            child: _probe((scope) => seen = scope),
          ),
        ),
      );
      expect(seen.startFrame, 150);
      expect(seen.durationFrames, 300);
      expect(seen.fps, 30);
      expect(seen.parent, const TimeScopeData(fps: 30, startFrame: 0, durationFrames: 600));
    });

    testWidgets('throws FluvieTimingError with no VideoScope above', (tester) async {
      await tester.pumpWidget(SceneScope(duration: 10.seconds, child: const SizedBox.shrink()));
      expect(tester.takeException(), isA<FluvieTimingError>());
    });
  });

  group('nested resolution', () {
    testWidgets('0.5.relative in a 10s scene @30fps resolves to 150', (tester) async {
      late TimeScopeData scene;
      await tester.pumpWidget(
        VideoScope(
          fps: 30,
          duration: 20.seconds,
          child: SceneScope(duration: 10.seconds, child: _probe((scope) => scene = scope)),
        ),
      );
      expect(0.5.relative.resolveFrames(scene), 150);
      // Against the video the same Time means half of 20s instead.
      expect(0.5.relative.resolveFrames(scene.parent!), 300);
    });

    testWidgets('seconds resolve identically at video and scene level', (tester) async {
      late TimeScopeData scene;
      await tester.pumpWidget(
        VideoScope(
          fps: 30,
          duration: 20.seconds,
          child: SceneScope(duration: 10.seconds, child: _probe((scope) => scene = scope)),
        ),
      );
      expect(2.seconds.resolveFrames(scene), 60);
      expect(2.seconds.resolveFrames(scene.parent!), 60);
    });

    testWidgets('frame counts are scope-independent', (tester) async {
      late TimeScopeData scene;
      await tester.pumpWidget(
        VideoScope(
          fps: 30,
          duration: 20.seconds,
          child: SceneScope(duration: 10.seconds, child: _probe((scope) => scene = scope)),
        ),
      );
      expect(45.frames.resolveFrames(scene), 45);
      expect(45.frames.resolveFrames(scene.parent!), 45);
    });
  });
}
