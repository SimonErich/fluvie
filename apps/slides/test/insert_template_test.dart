import 'package:flutter/gestures.dart' show PointerDeviceKind, kSecondaryButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData;
import 'package:slides/editor/editor_screen.dart';

import 'desktop_surface.dart';
import 'memory_autosave_store.dart';

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'theme': {
    'palette': {'accent': '#123456'},
  },
  'scenes': [
    {'duration': '60f', 'layout': 'canvas', 'children': <Object?>[]},
  ],
};

Future<void> _pump(WidgetTester tester) async {
  useDesktopSurface(tester);
  await tester.pumpWidget(
    OiApp(
      title: 'test',
      theme: OiThemeData.dark(),
      home: EditorScreen(
        document: EditorDocument.fromJson(_deck()),
        title: 'mine.fluvie',
        onClose: () {},
        autosave: MemoryAutosaveStore(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('a template slide inserts with its tokens and master, undoable as one', (
    tester,
  ) async {
    await _pump(tester);
    // Right-click the slide tile for its menu.
    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryButton,
    );
    final where = tester.getCenter(find.text('1'));
    await gesture.addPointer(location: where);
    addTearDown(gesture.removePointer);
    await gesture.down(where);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Insert template: Pitch deck'));
    await tester.pumpAndSettle();

    final document = tester.widget<EditorCanvas>(find.byType(EditorCanvas)).document;
    expect(document.sceneCount, 2);
    expect(document.sceneMasterName(1), isNotNull, reason: 'the template slide adopts');
    expect(document.masterNames, isNotEmpty, reason: 'the needed master merged in');
    final palette = document.themeJson!['palette']! as Map<String, Object?>;
    expect(palette['accent'], '#123456', reason: 'existing deck tokens win');
    expect(palette.containsKey('background'), isTrue, reason: 'missing tokens arrive');

    // One undo step reverts the slide and the merge together.
    await tester.tap(find.bySemanticsLabel('Undo'));
    await tester.pump();
    final undone = tester.widget<EditorCanvas>(find.byType(EditorCanvas)).document;
    expect(undone.sceneCount, 1);
    expect(undone.masterNames, isEmpty);
    expect(undone.themeJson!['palette'], {'accent': '#123456'});
  });
}
