import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';
import 'package:slides/routing/speaker_route.dart';
import 'package:slides/slides_app.dart';
import 'package:slides/speaker_app.dart';

void main() {
  testWidgets('boots to the deck picker', (tester) async {
    await tester.pumpWidget(const SlidesApp());
    await tester.pump();
    expect(find.text('fluvie slides'), findsOneWidget);
    expect(find.text('Plain slides'), findsOneWidget);
    expect(find.text('The full talk'), findsOneWidget);
    expect(find.text('Open a .fluvie file'), findsOneWidget);
  });

  testWidgets('picking a deck presents it, and X returns to the picker', (tester) async {
    await tester.pumpWidget(const SlidesApp());
    await tester.pump();
    await tester.tap(find.text('Plain slides'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(FluvieSlides), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('fluvie slides'), findsWidgets);

    await tester.tap(find.bySemanticsLabel(RegExp('Back to .*picker')), warnIfMissed: false);
    await tester.pump();
    expect(find.byType(FluvieSlides), findsNothing);
    expect(find.text('Plain slides'), findsOneWidget);
  });

  testWidgets('off the web there is no speaker route, and the speaker shell says so', (
    tester,
  ) async {
    expect(isSpeakerRoute(), isFalse);
    expect(readSpeakerDeck(), isNull);
    await tester.pumpWidget(const SpeakerApp());
    await tester.pump();
    expect(find.textContaining('Nothing is being presented yet'), findsOneWidget);
  });
}
