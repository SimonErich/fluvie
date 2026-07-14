import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';

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

Video _deck({List<int>? probeSink, List<Scene>? scenes}) => Video(
  width: 320,
  height: 180,
  scenes:
      scenes ??
      [
        Scene(
          duration: const Time.seconds(4),
          children: [
            const Text('slide one', style: TextStyle(fontSize: 16)),
            Stop.single(
              child: KeyedSubtree(
                key: const ValueKey('step1'),
                child: _FrameProbe(probeSink ?? []),
              ),
            ),
            Stop.single(child: const SizedBox(width: 4, height: 4, key: ValueKey('step2'))),
          ],
        ),
        const Scene(
          duration: Time.seconds(4),
          children: [Text('slide two', style: TextStyle(fontSize: 16))],
        ),
      ],
);

(ProviderContainer, Widget) _present(
  Video video, {
  bool playTransitions = true,
  LivePlaybackController Function(int fps)? clockFactory,
}) {
  final container = ProviderContainer(
    overrides: [slidePlansProvider.overrideWithValue(compileSlidePlans(video))],
  );
  addTearDown(container.dispose);
  final widget = UncontrolledProviderScope(
    container: container,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: SlideView(video: video, playTransitions: playTransitions, clockFactory: clockFactory),
    ),
  );
  return (container, widget);
}

void main() {
  testWidgets('renders slide 0 at step 0 with stopped content absent', (tester) async {
    final (_, widget) = _present(_deck());
    await tester.pumpWidget(widget);
    await tester.pump();
    expect(find.text('slide one'), findsOneWidget);
    expect(find.byKey(const ValueKey('step1')), findsNothing);
    expect(find.byKey(const ValueKey('step2')), findsNothing);
  });

  testWidgets('a forward advance reveals the step on a rebased clock', (tester) async {
    final frames = <int>[];
    final (container, widget) = _present(_deck(probeSink: frames));
    await tester.pumpWidget(widget);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    container.read(presentationControllerProvider.notifier).next();
    await tester.pump();
    expect(find.byKey(const ValueKey('step1')), findsOneWidget);
    expect(find.byKey(const ValueKey('step2')), findsNothing);
    // The revealed subtree starts its clock at the reveal moment.
    expect(frames.last, lessThanOrEqualTo(1));
    await tester.pump(const Duration(seconds: 1));
    // And it advances with the running slide clock: ambient stays alive.
    expect(frames.last, greaterThanOrEqualTo(29));
  });

  testWidgets('back hides the step again instantly', (tester) async {
    final (container, widget) = _present(_deck());
    await tester.pumpWidget(widget);
    await tester.pump();
    container.read(presentationControllerProvider.notifier).next();
    await tester.pump();
    expect(find.byKey(const ValueKey('step1')), findsOneWidget);
    container.read(presentationControllerProvider.notifier).back();
    await tester.pump();
    expect(find.byKey(const ValueKey('step1')), findsNothing);
  });

  testWidgets('a jump lands on settled steps', (tester) async {
    final frames = <int>[];
    final (container, widget) = _present(_deck(probeSink: frames));
    await tester.pumpWidget(widget);
    await tester.pump();
    container.read(presentationControllerProvider.notifier).jumpToStep(0, 2);
    await tester.pump();
    expect(find.byKey(const ValueKey('step1')), findsOneWidget);
    expect(find.byKey(const ValueKey('step2')), findsOneWidget);
    // Settled: the subtree clock starts past its (zero-length) entrance and
    // keeps running.
    final settled = frames.last;
    await tester.pump(const Duration(seconds: 1));
    expect(frames.last, greaterThan(settled));
  });

  testWidgets('re-revealing forward after back plays a fresh entrance', (tester) async {
    final frames = <int>[];
    final (container, widget) = _present(_deck(probeSink: frames));
    await tester.pumpWidget(widget);
    await tester.pump();
    final controller = container.read(presentationControllerProvider.notifier)..next();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    controller.back();
    await tester.pump();
    controller.next();
    await tester.pump();
    // A fresh reveal: the subtree clock rebased to the new reveal moment.
    expect(frames.last, lessThanOrEqualTo(1));
  });

  testWidgets('advancing past the last step cuts to the next slide', (tester) async {
    final (container, widget) = _present(_deck(), playTransitions: false);
    await tester.pumpWidget(widget);
    await tester.pump();
    container.read(presentationControllerProvider.notifier)
      ..next()
      ..next()
      ..next();
    await tester.pump();
    expect(find.text('slide two'), findsOneWidget);
    expect(find.text('slide one'), findsNothing);
  });

  testWidgets('an authored crossFade blends between slides, then settles', (tester) async {
    final video = _deck(
      scenes: const [
        Scene(
          duration: Time.seconds(2),
          exit: Transition.crossFade(Time.seconds(0.5)),
          children: [Text('slide one', style: TextStyle(fontSize: 16))],
        ),
        Scene(
          duration: Time.seconds(2),
          children: [Text('slide two', style: TextStyle(fontSize: 16))],
        ),
      ],
    );
    final (container, widget) = _present(video);
    await tester.pumpWidget(widget);
    await tester.pump();
    container.read(presentationControllerProvider.notifier).next();
    await tester.pump();
    // Mid-blend: both slides are on stage.
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('slide one'), findsOneWidget);
    expect(find.text('slide two'), findsOneWidget);
    // After the window the outgoing slide unmounts (the swap settles on the
    // frame after the blend completes).
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('slide one'), findsNothing);
    expect(find.text('slide two'), findsOneWidget);
  });

  testWidgets('a settling blend keeps the incoming slide mounted and its clock running', (
    tester,
  ) async {
    // The double-entrance bug: when the blend completed, the incoming stage
    // remounted, its fresh ticker restarted at zero elapsed, and the slide
    // replayed its entrance. The stage must survive the swap, and the
    // probe's frames must never rewind.
    final frames = <int>[];
    final video = _deck(
      scenes: [
        const Scene(
          duration: Time.seconds(2),
          exit: Transition.crossFade(Time.seconds(0.5)),
          children: [Text('slide one', style: TextStyle(fontSize: 16))],
        ),
        Scene(duration: const Time.seconds(4), children: [_FrameProbe(frames)]),
      ],
    );
    final (container, widget) = _present(video);
    await tester.pumpWidget(widget);
    await tester.pump();
    container.read(presentationControllerProvider.notifier).next();
    await tester.pump();
    // Mid-blend: two players on stage; remember the incoming one's state.
    final duringBlend = tester.stateList<State<LivePlayer>>(find.byType(LivePlayer)).toSet();
    expect(duringBlend, hasLength(2));
    // Let the blend complete and settle (the swap lands one frame later).
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final settled = tester.state<State<LivePlayer>>(find.byType(LivePlayer));
    expect(
      duringBlend.contains(settled),
      isTrue,
      reason: 'the incoming stage must survive the blend settling, not remount',
    );
    for (var i = 1; i < frames.length; i++) {
      expect(
        frames[i],
        greaterThanOrEqualTo(frames[i - 1]),
        reason: 'the slide clock must never rewind (saw ${frames[i - 1]} then ${frames[i]})',
      );
    }
  });

  testWidgets('back across a slide boundary lands instantly on the last step', (tester) async {
    final (container, widget) = _present(_deck());
    await tester.pumpWidget(widget);
    await tester.pump();
    final controller = container.read(presentationControllerProvider.notifier)..jumpToSlide(1);
    await tester.pump();
    expect(find.text('slide two'), findsOneWidget);
    controller.back();
    await tester.pump();
    // Slide 0 at its LAST step: both stops settled, no blend.
    expect(find.text('slide one'), findsOneWidget);
    expect(find.byKey(const ValueKey('step1')), findsOneWidget);
    expect(find.byKey(const ValueKey('step2')), findsOneWidget);
    expect(find.text('slide two'), findsNothing);
  });

  testWidgets('an instant slide change never ticks the retired clock', (tester) async {
    // Real clocks on real tickers: the retired slide's player delivers one
    // more tick before the rebuild unmounts it, and that tick must not land
    // on a disposed controller.
    final (container, widget) = _present(_deck(), playTransitions: false);
    await tester.pumpWidget(widget);
    await tester.pump();
    final controller = container.read(presentationControllerProvider.notifier);
    for (var move = 0; move < 3; move++) {
      controller.next(); // two reveals, then the slide change
      await tester.pump(const Duration(milliseconds: 40));
    }
    expect(tester.takeException(), isNull);
    expect(find.text('slide two'), findsOneWidget);
  });

  testWidgets('an injected clock factory drives every slide mount', (tester) async {
    final clocks = <LivePlaybackController>[];
    final (container, widget) = _present(
      _deck(),
      clockFactory: (fps) {
        final clock = LivePlaybackController(fps: fps);
        clocks.add(clock);
        return clock;
      },
    );
    await tester.pumpWidget(widget);
    await tester.pump();
    expect(clocks, hasLength(1));
    container.read(presentationControllerProvider.notifier).jumpToSlide(1);
    await tester.pump();
    expect(clocks, hasLength(2));
  });
}
