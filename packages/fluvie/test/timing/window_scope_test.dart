import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/timing/scene_scope.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';
import 'package:fluvie/src/timing/video_scope.dart';
import 'package:fluvie/src/timing/window_scope.dart';

/// A leaf that reports the nearest scope to [onScope].
Widget _probe(void Function(TimeScopeData scope) onScope) => Builder(
  builder: (context) {
    onScope(TimeScopeProvider.of(context));
    return const SizedBox.shrink();
  },
);

void main() {
  group('WindowScope', () {
    testWidgets('a window mounts a nested scope at absolute frames', (tester) async {
      late TimeScopeData seen;
      await tester.pumpWidget(
        VideoScope(
          fps: 30,
          duration: 20.seconds,
          child: SceneScope(
            duration: 10.seconds,
            start: 5.seconds,
            child: WindowScope(
              window: 2.seconds.to(6.seconds),
              child: _probe((scope) => seen = scope),
            ),
          ),
        ),
      );
      expect(seen.startFrame, 210);
      expect(seen.durationFrames, 120);
      expect(seen.fps, 30);
      expect(seen.parent?.startFrame, 150);
    });

    testWidgets('no window: the scene stays the nearest scope', (tester) async {
      late TimeScopeData seen;
      await tester.pumpWidget(
        VideoScope(
          fps: 30,
          duration: 20.seconds,
          child: SceneScope(
            duration: 10.seconds,
            child: WindowScope(child: _probe((scope) => seen = scope)),
          ),
        ),
      );
      expect(seen.startFrame, 0);
      expect(seen.durationFrames, 300);
      expect(seen.parent?.durationFrames, 600);
    });

    testWidgets('throws FluvieTimingError with no scope above', (tester) async {
      await tester.pumpWidget(
        WindowScope(window: 1.seconds.to(2.seconds), child: const SizedBox.shrink()),
      );
      expect(tester.takeException(), isA<FluvieTimingError>());
    });
  });

  group('WindowScope.maybeWindowOf (WI-11, D22)', () {
    testWidgets('returns the range under a windowed scope', (tester) async {
      final window = 2.seconds.to(6.seconds);
      TimeRange? seen;
      await tester.pumpWidget(
        VideoScope(
          fps: 30,
          duration: 20.seconds,
          child: SceneScope(
            duration: 10.seconds,
            child: WindowScope(
              window: window,
              child: Builder(
                builder: (context) {
                  seen = WindowScope.maybeWindowOf(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );
      expect(seen, same(window));
    });

    testWidgets('returns null without a windowed scope — a window-less one carries nothing', (
      tester,
    ) async {
      TimeRange? seen = 1.seconds.to(2.seconds);
      await tester.pumpWidget(
        VideoScope(
          fps: 30,
          duration: 20.seconds,
          child: SceneScope(
            duration: 10.seconds,
            child: WindowScope(
              child: Builder(
                builder: (context) {
                  seen = WindowScope.maybeWindowOf(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );
      expect(seen, isNull);
    });

    testWidgets('the nearest windowed scope wins under nesting', (tester) async {
      final outer = 1.seconds.to(8.seconds);
      final inner = 2.seconds.to(6.seconds);
      TimeRange? seen;
      await tester.pumpWidget(
        VideoScope(
          fps: 30,
          duration: 20.seconds,
          child: SceneScope(
            duration: 10.seconds,
            child: WindowScope(
              window: outer,
              child: WindowScope(
                window: inner,
                child: Builder(
                  builder: (context) {
                    seen = WindowScope.maybeWindowOf(context);
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
        ),
      );
      expect(seen, same(inner));
    });

    testWidgets('a window-less scope passes the enclosing window through', (tester) async {
      final outer = 1.seconds.to(8.seconds);
      TimeRange? seen;
      await tester.pumpWidget(
        VideoScope(
          fps: 30,
          duration: 20.seconds,
          child: SceneScope(
            duration: 10.seconds,
            child: WindowScope(
              window: outer,
              child: WindowScope(
                child: Builder(
                  builder: (context) {
                    seen = WindowScope.maybeWindowOf(context);
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
        ),
      );
      expect(seen, same(outer));
    });
  });
}
