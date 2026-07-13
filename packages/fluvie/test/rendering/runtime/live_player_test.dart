import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/rendering/runtime/live_playback_controller.dart';
import 'package:fluvie/src/rendering/runtime/live_player.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';

/// Records the frame and render mode its subtree sees, per build.
class _Probe extends StatelessWidget {
  const _Probe(this.onBuild);

  final void Function(int frame, RenderMode mode) onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild(FrameProvider.of(context).frame, RenderModeContext.modeOf(context));
    return const SizedBox.shrink();
  }
}

void main() {
  testWidgets('publishes the controller frame in live (preview) mode', (tester) async {
    final controller = LivePlaybackController(fps: 30);
    addTearDown(controller.dispose);
    late int seenFrame;
    late RenderMode seenMode;
    await tester.pumpWidget(
      LivePlayer(
        controller: controller,
        child: _Probe((frame, mode) {
          seenFrame = frame;
          seenMode = mode;
        }),
      ),
    );
    expect(seenFrame, 0);
    expect(seenMode, RenderMode.preview);
  });

  testWidgets('the ticker advances the frame while playing', (tester) async {
    final controller = LivePlaybackController(fps: 30);
    addTearDown(controller.dispose);
    final frames = <int>[];
    await tester.pumpWidget(
      LivePlayer(controller: controller, child: _Probe((frame, _) => frames.add(frame))),
    );
    controller.play();
    // The first tick after start is the ticker's epoch (zero elapsed).
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(frames.last, 30);
    await tester.pump(const Duration(seconds: 1));
    expect(frames.last, 60);
  });

  testWidgets('seek lands exactly and hold stops the clock', (tester) async {
    final controller = LivePlaybackController(fps: 30);
    addTearDown(controller.dispose);
    final frames = <int>[];
    await tester.pumpWidget(
      LivePlayer(controller: controller, child: _Probe((frame, _) => frames.add(frame))),
    );
    controller.play();
    await tester.pump(const Duration(seconds: 1));
    controller.hold(7);
    await tester.pump();
    expect(frames.last, 7);
    await tester.pump(const Duration(seconds: 3));
    expect(frames.last, 7);
  });

  testWidgets('playRange stops exactly on its end frame', (tester) async {
    final controller = LivePlaybackController(fps: 30);
    addTearDown(controller.dispose);
    final frames = <int>[];
    await tester.pumpWidget(
      LivePlayer(controller: controller, child: _Probe((frame, _) => frames.add(frame))),
    );
    final done = controller.playRange(10, 25);
    await tester.pump();
    expect(frames.last, 10);
    await tester.pump(const Duration(seconds: 2));
    expect(frames.last, 25);
    await expectLater(done, completes);
    // Holding: no further advancement.
    await tester.pump(const Duration(seconds: 1));
    expect(frames.last, 25);
  });

  testWidgets('a paused player does not rebuild its subtree', (tester) async {
    final controller = LivePlaybackController(fps: 30);
    addTearDown(controller.dispose);
    var builds = 0;
    await tester.pumpWidget(
      LivePlayer(controller: controller, child: _Probe((_, _) => builds++)),
    );
    final before = builds;
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(builds, before);
  });

  testWidgets('swapping controllers rewires the ticker', (tester) async {
    final first = LivePlaybackController(fps: 30);
    final second = LivePlaybackController(fps: 30, initialFrame: 100);
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    final frames = <int>[];
    Widget playerWith(LivePlaybackController controller) =>
        LivePlayer(controller: controller, child: _Probe((frame, _) => frames.add(frame)));

    await tester.pumpWidget(playerWith(first));
    first.play();
    // The first tick after start is the ticker's epoch (zero elapsed).
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(frames.last, 30);

    await tester.pumpWidget(playerWith(second));
    expect(frames.last, 100);
    second.play();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(frames.last, 130);
    // The old controller no longer drives the tree.
    first.seek(5);
    await tester.pump();
    expect(frames.last, 130);
  });
}
