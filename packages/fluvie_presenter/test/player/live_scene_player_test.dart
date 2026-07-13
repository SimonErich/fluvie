import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';

/// Records every frame its build sees — mounted as scene content, so it
/// only builds while its scene is on stage.
class _FrameProbe extends StatelessWidget {
  const _FrameProbe(this.frames);

  final List<int> frames;

  @override
  Widget build(BuildContext context) {
    frames.add(FrameProvider.of(context).frame);
    return const SizedBox.shrink();
  }
}

Video _video(List<int> frames, {int scenes = 1}) => Video(
  width: 320,
  height: 180,
  scenes: [
    for (var s = 0; s < scenes; s++)
      Scene(duration: const Time.seconds(2), children: [if (s == scenes - 1) _FrameProbe(frames)]),
  ],
);

void main() {
  testWidgets('renders the video and plays its scene end to end', (tester) async {
    final frames = <int>[];
    await tester.pumpWidget(LiveScenePlayer(video: _video(frames)));
    expect(find.byType(Video), findsOneWidget);
    expect(frames.first, 0);
    // Ticker epoch, then two seconds of playback: the scene is 60 frames at
    // 30 fps, and the range hold stops exactly on its last frame.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 3));
    expect(frames.last, 59);
  });

  testWidgets('autoPlay: false holds the scene start', (tester) async {
    final frames = <int>[];
    await tester.pumpWidget(LiveScenePlayer(video: _video(frames), autoPlay: false));
    await tester.pump(const Duration(seconds: 2));
    expect(frames.toSet(), {0});
  });

  testWidgets('sceneIndex targets a later scene at its absolute offset', (tester) async {
    final frames = <int>[];
    await tester.pumpWidget(LiveScenePlayer(video: _video(frames, scenes: 2), sceneIndex: 1));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    // Scene 1 spans frames 60..119; playback started on its first frame and
    // held its last.
    expect(frames.first, 60);
    expect(frames.last, 119);
  });

  testWidgets('an injected controller stays in charge and is not disposed', (tester) async {
    final frames = <int>[];
    final video = _video(frames);
    final controller = LivePlaybackController(fps: 30, totalFrames: 60);
    await tester.pumpWidget(LiveScenePlayer(video: video, controller: controller));
    expect(controller.state, LivePlaybackState.playing);
    controller.hold(10);
    await tester.pump();
    expect(frames.last, 10);
    await tester.pumpWidget(const SizedBox.shrink());
    // Still usable after the player unmounts: the player never owned it.
    controller.seek(3);
    expect(controller.frame, 3);
    controller.dispose();
  });
}
