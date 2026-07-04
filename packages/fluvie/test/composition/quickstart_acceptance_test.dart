// PHASE ACCEPTANCE (WI-25): the §3 quickstart, verbatim minus `Image.network`
// (the media path lands in Phase 8; a fixed-size stand-in carries the third
// element's animations unchanged). Proves the whole story end to end: a
// gradient background animates a `gradientShift` with relative timing under
// an `Anchor`, a `Text` waits on `Trigger.after(bg)`, and the resolved
// timeline tells the §3 narrative — "begins 1 s in", ends at 4 s.
//
// The spec passes `fps: 30` and `from: Edge.bottom` explicitly even though
// they are the defaults — the tree stays verbatim.
// ignore_for_file: avoid_redundant_argument_values
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/composition/background/background.dart';
import 'package:fluvie/src/composition/runtime/timeline_probe.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/edge.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/core/video_size.dart';
import 'package:fluvie/src/rendering/primitives/fade_box.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';

/// The §3 composition: 30 fps, one 10 s scene — frames 0..300, the shift
/// spanning 30..120 (1 s → 4 s) and the text entering 120..144.
Video _quickstart(Anchor bg) => Video(
  size: VideoSize.square,
  fps: 30,
  scenes: [
    Scene(
      duration: 10.seconds,
      children: [
        // A gradient that shifts color, named so others can react to it.
        Background.gradient(const [Colors.red, Colors.green]).animate([
          Animation.gradientShift(
            to: const [Colors.blue, Colors.green],
            duration: 0.3.relative, // 30% of the 10s scene
            delay: 0.1.relative, // begins 1s in
          ),
        ], anchor: bg),
        // Slides + fades in, but only once the gradient shift finishes.
        const Text(
          'Hello, Fluvie',
        ).animate([Animation.slideFade(from: Edge.bottom, at: Trigger.after(bg))]),
        // §3 mounts Image.network here — Phase 8 media; the stand-in keeps
        // the element's two animations verbatim.
        const SizedBox(
          width: 120,
          height: 90,
          child: ColoredBox(color: Color(0xFF888888)),
        ).animate([
          Animation.slideFade(from: Edge.left, duration: 4.seconds),
          Animation.kenBurns(zoom: 1.2),
        ]),
      ],
    ),
  ],
);

void main() {
  testWidgets('§3 quickstart: gradient anchor, Trigger.after, and the timeline narrative', (
    tester,
  ) async {
    final bg = Anchor('bg');
    final controller = RenderController();
    final probe = TimelineProbe();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RenderModeContext(
          mode: RenderMode.capture,
          child: RenderControllerScope(
            controller: controller,
            child: TimelineProbeScope(probe: probe, child: _quickstart(bg)),
          ),
        ),
      ),
    );

    Future<void> seek(int frame) async {
      controller.seek(frame);
      await tester.pump();
    }

    List<Color> paintedGradient() {
      final box = tester.widget<DecoratedBox>(
        find.descendant(of: find.byType(Background), matching: find.byType(DecoratedBox)),
      );
      return ((box.decoration as BoxDecoration).gradient! as LinearGradient).colors;
    }

    List<Color> shiftedBy(double t) => [
      Color.lerp(Colors.red, Colors.blue, t)!,
      Color.lerp(Colors.green, Colors.green, t)!,
    ];

    // FadeBox replaced the raw Opacity (D16-P6); it stays mounted at 1.0.
    double textOpacity() => tester
        .widget<FadeBox>(
          find.ancestor(of: find.text('Hello, Fluvie'), matching: find.byType(FadeBox)).first,
        )
        .opacity;

    // The gradient: base at 0 s, the shift begins 1 s in, is half-way (on the
    // default smooth ease) at 2.5 s, and holds the target from 4 s on.
    await seek(0);
    expect(paintedGradient(), shiftedBy(0));
    await seek(30);
    expect(paintedGradient(), shiftedBy(0));
    await seek(75);
    expect(paintedGradient(), shiftedBy(Ease.smooth.transform(0.5)));
    await seek(120);
    expect(paintedGradient(), shiftedBy(1));
    await seek(240);
    expect(paintedGradient(), shiftedBy(1));

    // The text: hidden strictly before 4 s, animating after, settled by
    // 120 + 24 frames (the package default duration, 0.8 s capped).
    await seek(60);
    expect(textOpacity(), 0.0);
    await seek(119);
    expect(textOpacity(), 0.0);
    await seek(132);
    expect(textOpacity(), allOf(greaterThan(0.0), lessThan(1.0)));
    await seek(144);
    expect(textOpacity(), 1.0);

    // The timeline narrative (§3): the named shift "begins 1s in" and runs
    // 30% of the scene; the follower starts exactly where it ends.
    final timeline = probe.value!;
    expect(timeline.warnings, isEmpty);
    expect(timeline.totalFrames, 300);
    final shift = timeline.rowsFor('s0e0:bg').single;
    expect((shift.startFrame, shift.endFrame), (30, 120));
    final follower = timeline.rowsFor('s0e1:Text').single;
    expect((follower.startFrame, follower.endFrame), (120, 144));
  });
}
