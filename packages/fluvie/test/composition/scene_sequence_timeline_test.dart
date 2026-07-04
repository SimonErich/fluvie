// WI-21 (D12, §8) — EPIC ACCEPTANCE. A Scene.sequence(timeline: tl) with a
// real 4-step Timeline derives the right Scene.duration AND the timeline drives
// its anchored children: the placement plan binds each child's animation at its
// resolved absolute start, so the composition resolver produces spans at the
// timeline positions (a probe debugTimeline shows the rows, warning-free), and
// mounted in a Video the scene offset and total match the derived length.

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
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';
import 'package:fluvie/src/timing/timeline/debug_timeline.dart';
import 'package:fluvie/src/timing/timeline/resolved_timeline.dart';

const _kTitle = Key('title');
const _kSubtitle = Key('subtitle');
const _kOne = Key('b1');
const _kTwo = Key('b2');

Animation _enter(int frames, {Trigger at = Trigger.auto}) => Animation.from(
  const Keyframe(opacity: 0),
  duration: Time.frames(frames),
  ease: Ease.linear,
  at: at,
);

/// The §8-shaped four-step timeline plus the bare anchored children it drives.
({Timeline timeline, List<Widget> children}) _sequence() {
  final title = Anchor('title');
  final subtitle = Anchor('subtitle');
  final one = Anchor('b1');
  final two = Anchor('b2');
  final timeline = Timeline()
    ..play(title, _enter(20))
    ..play(subtitle, _enter(15), at: Trigger.whenEnds(title))
    ..wait(const Time.frames(9))
    ..playAll([one, two], _enter(10), stagger: const Time.frames(4));
  final children = <Widget>[
    const SizedBox(key: _kTitle, width: 10, height: 10).animate(const [], anchor: title),
    const SizedBox(key: _kSubtitle, width: 10, height: 10).animate(const [], anchor: subtitle),
    const SizedBox(key: _kOne, width: 10, height: 10).animate(const [], anchor: one),
    const SizedBox(key: _kTwo, width: 10, height: 10).animate(const [], anchor: two),
  ];
  return (timeline: timeline, children: children);
}

Widget _harness(Video video, {required RenderController controller, TimelineProbe? probe}) =>
    RenderModeContext(
      mode: RenderMode.capture,
      child: RenderControllerScope(
        controller: controller,
        child: probe == null ? video : TimelineProbeScope(probe: probe, child: video),
      ),
    );

void main() {
  group('Scene.sequence with a real Timeline', () {
    test('derives the scene duration from the timeline', () {
      final sequenced = _sequence();
      final scene = Scene.sequence(
        timeline: sequenced.timeline,
        children: sequenced.children,
      );
      // title 0..20, subtitle 20..35, wait -> 44, bullets 44 & 48, last ends 58.
      expect(
        scene.duration.resolveFrames(
          const TimeScopeData(fps: 30, startFrame: 0, durationFrames: 0),
        ),
        58,
      );
    });

    testWidgets('mounted in a Video the offset and total match the derived length', (tester) async {
      final sequenced = _sequence();
      final controller = RenderController();
      final video = Video(
        width: 320,
        height: 240,
        scenes: [
          Scene(duration: 30.frames, children: const [SizedBox(width: 4, height: 4)]),
          Scene.sequence(timeline: sequenced.timeline, children: sequenced.children),
        ],
      );
      await tester.pumpWidget(_harness(video, controller: controller));
      await tester.pump();

      expect(video.sceneStartFrames, [0, 30]);
      expect(video.totalFrames, 30 + 58);
    });

    testWidgets('the timeline drives anchored children to the right spans (warning-free)', (
      tester,
    ) async {
      final sequenced = _sequence();
      final controller = RenderController();
      final probe = TimelineProbe();
      final video = Video(
        width: 320,
        height: 240,
        scenes: [Scene.sequence(timeline: sequenced.timeline, children: sequenced.children)],
      );
      await tester.pumpWidget(_harness(video, controller: controller, probe: probe));
      await tester.pump();

      final timeline = probe.value;
      expect(timeline, isNotNull);
      expect(timeline!.warnings, isEmpty);
      expect(timeline.totalFrames, 58);

      // The bound children resolve to the timeline's placement spans.
      expect(_spanOf(timeline, 'title'), (0, 20));
      expect(_spanOf(timeline, 'subtitle'), (20, 35));
      expect(_spanOf(timeline, 'b1'), (44, 54));
      expect(_spanOf(timeline, 'b2'), (48, 58));

      // debugTimeline renders the anchored rows.
      final text = debugTimeline(timeline);
      expect(text, contains('title'));
      expect(text, contains('subtitle'));
    });
  });
}

/// The single resolved span (start, end) of the row owned by the anchor named
/// [anchorName] in [timeline].
(int, int) _spanOf(ResolvedTimeline timeline, String anchorName) {
  final row = timeline.rows.firstWhere((row) => row.ownerId.contains(anchorName));
  return (row.startFrame, row.endFrame);
}
