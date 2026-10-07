import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show LivePlayer;
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData;

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': <Object?>[
    {
      'duration': '120f',
      'children': [
        {'id': 'el-one', 'type': 'Text', 'text': 'scene one'},
      ],
    },
    {
      'duration': '90f',
      'children': [
        {'id': 'el-two', 'type': 'Text', 'text': 'scene two'},
      ],
    },
  ],
};

Future<void> _pump(
  WidgetTester tester,
  EditorDocument document,
  SlideTransport transport, {
  int slide = 0,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: OiApp(
        title: 'test',
        theme: OiThemeData.dark(),
        home: EditorCanvas(
          document: document,
          slide: slide,
          fitMargin: 0,
          wholeDocument: true,
          transport: transport,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('the whole-document canvas crosses scene boundaries with the transport', (
    tester,
  ) async {
    final document = EditorDocument.fromJson(_deck());
    final timebase = VideoTimebase.of(document);
    final transport = SlideTransport(fps: 30, length: timebase.totalFrames);
    addTearDown(transport.dispose);
    await _pump(tester, document, transport);

    // Frame 0 sits in scene one; only scene one's content is on stage.
    expect(find.text('scene one'), findsOneWidget);
    expect(find.text('scene two'), findsNothing);

    // Scrub across the boundary: absolute frame 130 = scene two, local 10.
    transport.seek(130);
    await tester.pump();
    expect(find.text('scene two'), findsOneWidget);
    expect(find.text('scene one'), findsNothing);
    expect(transport.frame, 130);
    expect(timebase.sceneAt(transport.frame), 1);
    expect(transport.frame - timebase.sceneSpans[1].start, 10);

    // The stage mounts the transport's own clock — one truth, no copies.
    final player = tester.widget<LivePlayer>(find.byType(LivePlayer));
    expect(identical(player.controller, transport.controller), isTrue);
  });

  testWidgets('a document edit re-derives the mounted video', (tester) async {
    final document = EditorDocument.fromJson(_deck());
    final transport = SlideTransport(fps: 30, length: 210);
    addTearDown(transport.dispose);
    await _pump(tester, document, transport);
    expect(find.text('scene one'), findsOneWidget);

    final edited = document.replaceElement('el-one', {
      ...document.elementJson('el-one')!,
      'text': 'retitled',
    });
    await _pump(tester, edited, transport);
    expect(find.text('retitled'), findsOneWidget);
    expect(find.text('scene one'), findsNothing);
  });
}
