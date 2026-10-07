import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart';

void main() {
  testWidgets('audio workspace edits stops and solo stays out of history', (tester) async {
    final history = DocumentHistory(
      EditorDocument.fromJson(const {
        'fluvieSpec': 1,
        'fps': 30,
        'size': {'width': 320, 'height': 180},
        'scenes': [
          {'duration': '2s'},
        ],
        'lanes': [
          {'id': 'bed', 'kind': 'audio', 'name': 'Music'},
        ],
        'audio': [
          {
            'kind': 'music',
            'source': {'kind': 'asset', 'value': 'bed.wav'},
            'lane': 'bed',
          },
        ],
      }),
    );
    addTearDown(history.dispose);
    await tester.pumpWidget(
      OiApp(
        title: 'test',
        theme: OiThemeData.dark(),
        home: Center(
          child: SizedBox(
            width: 320,
            child: ListenableBuilder(
              listenable: history,
              builder: (context, _) => AudioWorkspacePanel(
                document: history.document,
                timebase: VideoTimebase.of(history.document),
                currentFrame: 30,
                onCommand: history.dispatch,
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final solo = find.text('Solo monitor');
    await tester.ensureVisible(solo);
    await tester.tap(solo);
    await tester.pump();
    expect(history.canUndo, isFalse);
    final add = find.text('Add volume stop');
    await tester.scrollUntilVisible(add, 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(add);
    await tester.pump();
    expect(history.document.spec.audio.single.automation.values, [1, 0.5, 1]);
    expect(tester.takeException(), isNull);
    history.undo();
    await tester.pump();
    expect(history.document.spec.audio.single.automation.isEmpty, isTrue);
  });
}
