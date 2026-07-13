import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';
import 'package:fluvie_presenter/src/speaker/speaker_sync_binding.dart';

import 'fake_sync_channel.dart';

List<SlidePlan> _deck(List<int> steps) => [
  for (var s = 0; s < steps.length; s++)
    SlidePlan(
      sceneIndex: s,
      steps: [
        for (var k = 0; k < steps[s]; k++) SlideStep(index: k, stops: const [], entranceFrames: 0),
      ],
    ),
];

void main() {
  testWidgets('two windows bridged by the channel stay in lockstep', (tester) async {
    final pair = FakeSyncChannelPair();
    final plans = _deck([3, 2]);
    final mainContainer = ProviderContainer(
      overrides: [
        slidePlansProvider.overrideWithValue(plans),
        presentationSyncChannelProvider.overrideWithValue(pair.main),
      ],
    );
    final speakerContainer = ProviderContainer(
      overrides: [
        slidePlansProvider.overrideWithValue(plans),
        presentationSyncChannelProvider.overrideWithValue(pair.speaker),
      ],
    );
    addTearDown(mainContainer.dispose);
    addTearDown(speakerContainer.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            UncontrolledProviderScope(
              container: mainContainer,
              child: const SpeakerSyncBinding(child: SizedBox.shrink()),
            ),
            UncontrolledProviderScope(
              container: speakerContainer,
              child: const SpeakerSyncBinding(isPrimary: false, child: SizedBox.shrink()),
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    PresentationPosition mainAt() => mainContainer.read(presentationControllerProvider).position;
    PresentationPosition speakerAt() =>
        speakerContainer.read(presentationControllerProvider).position;

    // Main navigates forward through steps and a slide boundary.
    mainContainer.read(presentationControllerProvider.notifier)
      ..next()
      ..next()
      ..next();
    await tester.pump();
    expect(mainAt(), const PresentationPosition(1, 0));
    expect(speakerAt(), const PresentationPosition(1, 0));

    // The speaker requests moves; the main applies and broadcasts back.
    pair.speaker.send(const NavigationRequest.back());
    await tester.pump();
    expect(mainAt(), const PresentationPosition(0, 2));
    expect(speakerAt(), const PresentationPosition(0, 2));

    pair.speaker.send(const NavigationRequest.jump(PresentationPosition(1, 1)));
    await tester.pump();
    expect(mainAt(), const PresentationPosition(1, 1));
    expect(speakerAt(), const PresentationPosition(1, 1));

    // Instant seeks (back and jump) land both ends without echo storms.
    mainContainer.read(presentationControllerProvider.notifier).jumpToSlide(0);
    await tester.pump();
    await tester.pump();
    expect(mainAt(), const PresentationPosition(0, 0));
    expect(speakerAt(), const PresentationPosition(0, 0));
  });

  testWidgets('a late-joining speaker learns the position on bind', (tester) async {
    final pair = FakeSyncChannelPair();
    final plans = _deck([2, 2]);
    final mainContainer = ProviderContainer(
      overrides: [
        slidePlansProvider.overrideWithValue(plans),
        presentationSyncChannelProvider.overrideWithValue(pair.main),
      ],
    );
    final speakerContainer = ProviderContainer(
      overrides: [
        slidePlansProvider.overrideWithValue(plans),
        presentationSyncChannelProvider.overrideWithValue(pair.speaker),
      ],
    );
    addTearDown(mainContainer.dispose);
    addTearDown(speakerContainer.dispose);
    // The main window has already presented ahead...
    mainContainer.read(presentationControllerProvider.notifier).jumpToStep(1, 1);

    // ...and only then do both bindings mount (speaker first, so it is
    // listening when the primary announces itself).
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            UncontrolledProviderScope(
              container: speakerContainer,
              child: const SpeakerSyncBinding(isPrimary: false, child: SizedBox.shrink()),
            ),
            UncontrolledProviderScope(
              container: mainContainer,
              child: const SpeakerSyncBinding(child: SizedBox.shrink()),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(
      speakerContainer.read(presentationControllerProvider).position,
      const PresentationPosition(1, 1),
    );
  });

  testWidgets('without a channel the binding is a passthrough', (tester) async {
    final container = ProviderContainer(
      overrides: [
        slidePlansProvider.overrideWithValue(_deck([2])),
        presentationSyncChannelProvider.overrideWithValue(null),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SpeakerSyncBinding(child: SizedBox(key: ValueKey('through'))),
      ),
    );
    expect(find.byKey(const ValueKey('through')), findsOneWidget);
    container.read(presentationControllerProvider.notifier).next();
    await tester.pump();
    expect(
      container.read(presentationControllerProvider).position,
      const PresentationPosition(0, 1),
    );
  });
}
