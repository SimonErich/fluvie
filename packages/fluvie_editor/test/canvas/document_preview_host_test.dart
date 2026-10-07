import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show Video;
import 'package:fluvie_editor/fluvie_editor.dart';

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'layout': 'canvas',
      'background': {'kind': 'color', 'color': '#223344'},
      'children': [
        {
          'id': 'el-box',
          'type': 'Box',
          'color': '#6C5CE7',
          'transform': {'x': 0.5, 'y': 0.5, 'w': 0.4, 'h': 0.4},
        },
      ],
    },
    {'duration': '30f', 'children': <Object?>[]},
  ],
};

void main() {
  testWidgets('the hidden host renders a document slide to a thumbnail', (tester) async {
    final hostKey = GlobalKey<DocumentPreviewHostState>();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              child: DocumentPreviewHost(
                key: hostKey,
                document: EditorDocument.fromJson(_deck()),
              ),
            ),
          ],
        ),
      ),
    );
    // Idle host: nothing mounted.
    expect(find.byType(Video), findsNothing);

    final pending = hostKey.currentState!.render(0);
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    final image = await tester.runAsync(() => pending);
    expect(image!.width, 320);
    expect(image.height, 180);
    await tester.pump();
    expect(find.byType(Video), findsNothing);

    // A second slide renders through the same serialized stage.
    final second = hostKey.currentState!.render(1);
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    expect((await tester.runAsync(() => second))!.width, 320);
    await tester.pump();
  });
}
