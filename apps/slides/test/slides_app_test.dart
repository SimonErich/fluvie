import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';
import 'package:obers_ui/obers_ui.dart' show OiFileDropTarget;
import 'package:slides/loader/open_fluvie_file.dart';
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
    // The picker is also a drop target for .fluvie files.
    expect(find.byType(OiFileDropTarget), findsOneWidget);
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

  testWidgets('opening a file presents it; a broken file shows the error', (tester) async {
    const good =
        '{"fluvieSpec": 1, "size": "hd", "fps": 30, "scenes": '
        '[{"duration": "60f", "children": [{"type": "Text", "text": "hi", '
        '"style": {"color": "#FFFFFF", "fontSize": 40}}]}]}';
    var next = parseFluvieJson('good.fluvie', good);
    await tester.pumpWidget(SlidesApp(openFile: () async => next));
    await tester.pump();
    await tester.tap(find.text('Open a .fluvie file'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(FluvieSlides), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.bySemanticsLabel(RegExp('Back to .*picker')), warnIfMissed: false);
    await tester.pump();
    next = parseFluvieJson('broken.fluvie', '{not json');
    await tester.tap(find.text('Open a .fluvie file'));
    await tester.pump();
    expect(find.byType(FluvieSlides), findsNothing);
    expect(find.textContaining('broken.fluvie'), findsOneWidget);
  });

  testWidgets('the speaker shell resolves a bundled deck, a file, and the unknowns', (
    tester,
  ) async {
    await tester.pumpWidget(SpeakerApp(readDeck: () => (kind: 'bundled', payload: 'welcome')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(FluvieSpeaker), findsOneWidget);

    await tester.pumpWidget(SpeakerApp(readDeck: () => (kind: 'bundled', payload: 'nope')));
    await tester.pump();
    expect(find.textContaining('Unknown deck'), findsOneWidget);

    final json = jsonEncode({
      'fluvieSpec': 1,
      'size': 'hd',
      'fps': 30,
      'scenes': [
        {
          'duration': '60f',
          'children': [
            {
              'type': 'Text',
              'text': 'hi',
              'style': {'color': '#FFFFFF', 'fontSize': 40},
            },
          ],
        },
      ],
    });
    await tester.pumpWidget(SpeakerApp(readDeck: () => (kind: 'file', payload: json)));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(FluvieSpeaker), findsOneWidget);

    await tester.pumpWidget(SpeakerApp(readDeck: () => (kind: 'file', payload: '{broken')));
    await tester.pump();
    expect(find.textContaining('no longer parses'), findsOneWidget);
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
