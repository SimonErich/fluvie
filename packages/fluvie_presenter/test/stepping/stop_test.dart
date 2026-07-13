import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';
import 'package:fluvie_presenter/src/stepping/step_scope.dart';

/// Records the frames its build sees.
class _FrameProbe extends StatelessWidget {
  const _FrameProbe(this.frames);

  final List<int> frames;

  @override
  Widget build(BuildContext context) {
    frames.add(FrameProvider.of(context).frame);
    return const SizedBox(width: 8, height: 8);
  }
}

Video _video(List<Widget> sceneChildren) => Video(
  width: 320,
  height: 180,
  scenes: [Scene(duration: const Time.seconds(2), children: sceneChildren)],
);

Widget _present(Video video, LivePlaybackController controller, {Map<Stop, StopState>? states}) {
  final player = LivePlayer(controller: controller, child: video);
  return states == null ? player : StepScope(states: states, child: player);
}

void main() {
  testWidgets('without a StepScope the Stop is a transparent passthrough', (tester) async {
    const stop = Stop(children: [Text('revealed', style: TextStyle(fontSize: 16))]);
    final controller = LivePlaybackController(fps: 30);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: _present(_video([stop]), controller),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('revealed'), findsOneWidget);
  });

  testWidgets('children are absent before their step and present after', (tester) async {
    const stop = Stop(children: [SizedBox(width: 8, height: 8, key: ValueKey('late'))]);
    final controller = LivePlaybackController(fps: 30);
    addTearDown(controller.dispose);
    Widget at(StopState state) => _present(_video([stop]), controller, states: {stop: state});

    await tester.pumpWidget(at(const HiddenStop()));
    await tester.pump();
    expect(find.byKey(const ValueKey('late')), findsNothing);

    await tester.pumpWidget(at(const RevealedStop(baseFrame: 0)));
    await tester.pump();
    expect(find.byKey(const ValueKey('late')), findsOneWidget);
  });

  testWidgets('a revealed Stop rebases its subtree clock to the reveal frame', (tester) async {
    final frames = <int>[];
    final stop = Stop(children: [_FrameProbe(frames)]);
    final controller = LivePlaybackController(fps: 30);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _present(_video([stop]), controller, states: {stop: const RevealedStop(baseFrame: 45)}),
    );
    controller.seek(45);
    await tester.pump();
    expect(frames.last, 0);
    controller.seek(60);
    await tester.pump();
    // The subtree clock runs on: 60 - 45 = 15.
    expect(frames.last, 15);
  });

  testWidgets('a settled Stop skips past its entrance and keeps running', (tester) async {
    final frames = <int>[];
    final stop = Stop(children: [_FrameProbe(frames)]);
    final controller = LivePlaybackController(fps: 30);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _present(
        _video([stop]),
        controller,
        states: {stop: const RevealedStop(baseFrame: 10, skipFrames: 24)},
      ),
    );
    controller.seek(10);
    await tester.pump();
    // Mounted at its settle point: entrances are already over.
    expect(frames.last, 24);
    controller.seek(40);
    await tester.pump();
    // Ambient time keeps flowing: 40 - 10 + 24 = 54.
    expect(frames.last, 54);
  });

  testWidgets('animated children inside a revealed Stop mount without a timing error', (
    tester,
  ) async {
    final stop = Stop(
      children: [
        const SizedBox(width: 8, height: 8).animate([Animation.fadeIn()]),
      ],
    );
    final controller = LivePlaybackController(fps: 30);
    addTearDown(controller.dispose);
    Widget at(StopState state) => _present(_video([stop]), controller, states: {stop: state});

    // Resolve the composition with the stop hidden, then reveal mid-flight:
    // the reveal must not hit the late-registration error.
    await tester.pumpWidget(at(const HiddenStop()));
    await tester.pump();
    await tester.pump();
    controller.seek(30);
    await tester.pumpWidget(at(const RevealedStop(baseFrame: 30)));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('several children in one Stop stack like scene siblings', (tester) async {
    const stop = Stop(
      children: [
        SizedBox(width: 8, height: 8, key: ValueKey('a')),
        SizedBox(width: 4, height: 4, key: ValueKey('b')),
      ],
    );
    final controller = LivePlaybackController(fps: 30);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _present(_video([stop]), controller, states: {stop: const RevealedStop(baseFrame: 0)}),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('a')), findsOneWidget);
    expect(find.byKey(const ValueKey('b')), findsOneWidget);
    // Both center on the same spot, like sibling scene children.
    expect(
      tester.getCenter(find.byKey(const ValueKey('a'))),
      tester.getCenter(find.byKey(const ValueKey('b'))),
    );
  });

  testWidgets('Stop.single wraps one child', (tester) async {
    final stop = Stop.single(child: const SizedBox(key: ValueKey('only')));
    final controller = LivePlaybackController(fps: 30);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _present(_video([stop]), controller, states: {stop: const RevealedStop(baseFrame: 0)}),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('only')), findsOneWidget);
  });

  test('the walkers see through a Stop (media inside stopped content resolves)', () {
    const stop = Stop(
      children: [SizedBox(key: ValueKey('inside'))],
    );
    final seen = <Key>[];
    walkSceneTree(
      const [
        Scene(duration: Time.seconds(1), children: [stop]),
      ],
      (widget) {
        final key = widget.key;
        if (key != null) seen.add(key);
      },
    );
    expect(seen, contains(const ValueKey('inside')));
  });

  test('stop order is carried as authored', () {
    expect(const Stop(children: []).order, isNull);
    expect(const Stop(order: 3, children: []).order, 3);
    expect(Stop.single(order: 2, child: const SizedBox()).order, 2);
  });
}
