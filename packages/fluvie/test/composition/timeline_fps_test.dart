// A Timeline has no fps of its own: every recorded step resolves at the
// enclosing Video's fps. Before 0.2.0 the timeline resolved eagerly at its own
// fps (default 30), so a Video(fps: 60) silently mistimed every seconds-based
// step by 2x. These tests pin the fix: the same timeline places its steps at
// frame 90 in a 60 fps video and frame 45 in a 30 fps one.

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/composition/runtime/timeline_probe.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/composition/timeline.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/keyframe.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';
import 'package:fluvie/src/timing/timeline/resolved_timeline.dart';

Animation _enter(Time duration) =>
    Animation.from(const Keyframe(opacity: 0), duration: duration, ease: Ease.linear);

/// One second of `a`, half a second of silence, then `b` — all in seconds, so
/// the resolved frames depend entirely on the video's fps.
({Timeline timeline, List<Widget> children}) _sequence() {
  final a = Anchor('a');
  final b = Anchor('b');
  final timeline = Timeline()
    ..play(a, _enter(const Time.seconds(1)))
    ..wait(const Time.seconds(0.5))
    ..play(b, _enter(const Time.seconds(1)));
  final children = <Widget>[
    const SizedBox(key: Key('a'), width: 10, height: 10).animate(const [], anchor: a),
    const SizedBox(key: Key('b'), width: 10, height: 10).animate(const [], anchor: b),
  ];
  return (timeline: timeline, children: children);
}

(int, int) _spanOf(ResolvedTimeline timeline, String owner) {
  final row = timeline.rows.firstWhere((r) => r.ownerId.contains(owner));
  return (row.startFrame, row.endFrame);
}

Future<ResolvedTimeline> _resolve(WidgetTester tester, {required int fps}) async {
  final sequenced = _sequence();
  final probe = TimelineProbe();
  final video = Video(
    width: 320,
    height: 240,
    fps: fps,
    scenes: [Scene.sequence(timeline: sequenced.timeline, children: sequenced.children)],
  );
  await tester.pumpWidget(
    RenderModeContext(
      mode: RenderMode.capture,
      child: RenderControllerScope(
        controller: RenderController(),
        child: TimelineProbeScope(probe: probe, child: video),
      ),
    ),
  );
  await tester.pump();
  return probe.value!;
}

void main() {
  group('Timeline resolves at the enclosing Video fps', () {
    testWidgets('at 60 fps the second step starts at frame 90', (tester) async {
      final timeline = await _resolve(tester, fps: 60);
      expect(_spanOf(timeline, 'a'), (0, 60));
      expect(_spanOf(timeline, 'b'), (90, 150));
      expect(timeline.totalFrames, 150);
    });

    testWidgets('at 30 fps the same timeline places at frame 45', (tester) async {
      final timeline = await _resolve(tester, fps: 30);
      expect(_spanOf(timeline, 'a'), (0, 30));
      expect(_spanOf(timeline, 'b'), (45, 75));
      expect(timeline.totalFrames, 75);
    });

    test('the schedule duration resolves per scope, not eagerly', () {
      final sequenced = _sequence();
      final duration = sequenced.timeline.duration;
      expect(
        duration.resolveFrames(const TimeScopeData(fps: 60, startFrame: 0, durationFrames: 0)),
        150,
      );
      expect(
        duration.resolveFrames(const TimeScopeData(fps: 30, startFrame: 0, durationFrames: 0)),
        75,
      );
    });
  });
}
