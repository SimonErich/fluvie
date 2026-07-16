import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';
import 'package:fluvie_presenter/src/speaker/speaker_view.dart';

import 'fake_sync_channel.dart';

Video _deck({String note = 'watch the pacing'}) => Video(
  width: 320,
  height: 180,
  scenes: [
    Scene(
      duration: const Time.seconds(2),
      children: [SpeakerNotes(text: note)],
    ),
    const Scene(duration: Time.seconds(2)),
  ],
);

void main() {
  testWidgets('presents the speaker screen and navigates locally without a channel', (
    tester,
  ) async {
    await tester.pumpWidget(FluvieSpeaker(_deck()));
    await tester.pump();
    expect(find.byType(SpeakerView), findsOneWidget);
    expect(find.text('watch the pacing'), findsOneWidget);
    expect(find.text('Slide 1 / 2'), findsOneWidget);

    // No transport on the VM: inputs move this window's own controller.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('Slide 2 / 2'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(find.text('Slide 1 / 2'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(find.text('Slide 2 / 2'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(find.text('Slide 1 / 2'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('Slide 2 / 2'), findsOneWidget);
  });

  testWidgets('with a channel, inputs travel as navigation requests', (tester) async {
    final pair = FakeSyncChannelPair();
    final received = <SyncMessage>[];
    pair.main.messages.listen(received.add);
    final outer = ProviderContainer(
      overrides: [presentationSyncChannelProvider.overrideWithValue(pair.speaker)],
    );
    addTearDown(outer.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: outer, child: FluvieSpeaker(_deck())),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(received, const [
      NavigationRequest.next(),
      NavigationRequest.back(),
      NavigationRequest.jump(PresentationPosition(0, 0)),
    ]);
    // The local controller did not move: the presenting window owns moves.
    expect(find.text('Slide 1 / 2'), findsOneWidget);

    // And when the presenting window answers, this screen follows.
    pair.main.send(const PositionUpdate(PresentationPosition(1, 0)));
    await tester.pump();
    await tester.pump();
    expect(find.text('Slide 2 / 2'), findsOneWidget);
  });

  testWidgets('swapping the deck recompiles and remounts', (tester) async {
    final first = _deck();
    await tester.pumpWidget(FluvieSpeaker(first));
    await tester.pump();
    expect(find.text('watch the pacing'), findsOneWidget);
    await tester.pumpWidget(FluvieSpeaker(_deck(note: 'fresh deck')));
    await tester.pump();
    expect(find.text('fresh deck'), findsOneWidget);
  });

  test('the launch results and default launcher answer honestly', () async {
    expect(const SpeakerLaunchResult.opened(), const SpeakerLaunchResult.opened());
    expect(
      const SpeakerLaunchResult.fallback(url: 'x'),
      const SpeakerLaunchResult.fallback(url: 'x'),
    );
    expect(
      const SpeakerLaunchResult.fallback(url: 'x').hashCode,
      const SpeakerLaunchResult.fallback(url: 'x').hashCode,
    );
    expect(
      const SpeakerLaunchResult.opened(),
      isNot(const SpeakerLaunchResult.fallback()),
    );
    final result = await const FallbackSpeakerLauncher().open();
    expect(result, const SpeakerLaunchResult.fallback());

    final bare = ProviderContainer();
    addTearDown(bare.dispose);
    // On the VM there is no window transport and no window opener.
    expect(bare.read(presentationSyncChannelProvider), isNull);
    expect(bare.read(speakerWindowLauncherProvider), isA<FallbackSpeakerLauncher>());
  });

  test('sync messages describe themselves', () {
    expect(
      const PositionUpdate(PresentationPosition(1, 2)).toString(),
      'PositionUpdate(PresentationPosition(1.2))',
    );
    expect(const NavigationRequest.next().toString(), 'NavigationRequest(next)');
    expect(
      const NavigationRequest.jump(PresentationPosition(0, 1)).toString(),
      'NavigationRequest(jump PresentationPosition(0.1))',
    );
    expect(
      const PositionUpdate(PresentationPosition(1, 2)),
      isNot(const PositionUpdate(PresentationPosition(2, 1))),
    );
    expect(
      const NavigationRequest.next().hashCode,
      const NavigationRequest.next().hashCode,
    );
  });
}
