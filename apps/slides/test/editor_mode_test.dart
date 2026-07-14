import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart' show EditorCanvas;
import 'package:slides/editor/demo_spec.dart';
import 'package:slides/loader/open_fluvie_file.dart';
import 'package:slides/slides_app.dart';

void main() {
  testWidgets('the picker opens the demo deck in Edit mode and returns', (tester) async {
    await tester.pumpWidget(const SlidesApp());
    await tester.pump();
    await tester.ensureVisible(find.text('Edit the demo deck'));
    await tester.tap(find.text('Edit the demo deck'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(EditorCanvas), findsOneWidget);
    expect(find.text('1 / 5'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Next slide'));
    await tester.pump();
    expect(find.text('2 / 5'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Previous slide'));
    await tester.pump();
    expect(find.text('1 / 5'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Close editor'));
    await tester.pump();
    expect(find.byType(EditorCanvas), findsNothing);
    expect(find.text('Edit the demo deck'), findsOneWidget);
  });

  testWidgets('editing a picked .fluvie file opens the canvas', (tester) async {
    const good =
        '{"fluvieSpec": 1, "size": "hd", "fps": 30, "scenes": '
        '[{"duration": "60f", "children": [{"type": "Text", "text": "hi", '
        '"style": {"color": "#FFFFFF", "fontSize": 40}}]}]}';
    await tester.pumpWidget(
      SlidesApp(openFile: () async => parseFluvieJson('mine.fluvie', good)),
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Edit a .fluvie file'));
    await tester.tap(find.text('Edit a .fluvie file'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(EditorCanvas), findsOneWidget);
    expect(find.text('mine.fluvie'), findsOneWidget);
  });

  test('the embedded demo spec parses and mirrors the repo demo', () {
    expect(demoSpecJson['fluvieSpec'], 1);
    expect((demoSpecJson['scenes']! as List), hasLength(5));
  });

  test('parseRawJson rejects non-object documents', () {
    expect(() => parseRawJson('[]'), throwsFormatException);
    expect(parseRawJson('{"scenes": []}'), isA<Map<String, Object?>>());
  });
}
