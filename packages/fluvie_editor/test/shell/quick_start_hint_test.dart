import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart';

void main() {
  test('each guide gate requires its actual action and undo restores the gate', () {
    var document = EditorDocument.fromJson(const {
      'fluvieSpec': 1,
      'scenes': [
        {'duration': '2s', 'children': <Object?>[]},
      ],
    });
    expect(quickStartStep(document, exported: false), QuickStartStep.importMedia);
    const source = {'kind': 'file', 'value': '/clip.mp4'};
    document = document.addMediaEntry(
      const MediaStoreEntry(
        id: 'clip',
        name: 'clip.mp4',
        kind: MediaStoreKind.video,
        source: source,
        duration: '2s',
        fps: 30,
      ),
    );
    expect(quickStartStep(document, exported: false), QuickStartStep.place);
    final history = DocumentHistory(document)
      ..dispatch(
        const InsertElementCommand(
          scene: 0,
          id: 'placed',
          element: {
            'type': 'Clip',
            'source': source,
          },
        ),
      );
    expect(quickStartStep(history.document, exported: false), QuickStartStep.trim);
    history.dispatch(
      const UpdateMediaEntryCommand(
        entry: MediaStoreEntry(
          id: 'clip',
          name: 'clip.mp4',
          kind: MediaStoreKind.video,
          source: source,
          duration: '2s',
          fps: 30,
          inFrames: 10,
        ),
      ),
    );
    expect(quickStartStep(history.document, exported: false), QuickStartStep.export);
    expect(quickStartStep(history.document, exported: true), QuickStartStep.complete);
    history.undo();
    expect(quickStartStep(history.document, exported: false), QuickStartStep.trim);
  });
  test('a still-image project can export without source trim', () {
    final document =
        EditorDocument.fromJson(const {
          'fluvieSpec': 1,
          'scenes': [
            {
              'duration': '2s',
              'children': [
                {
                  'type': 'Image',
                  'source': {'kind': 'file', 'value': '/photo.png'},
                },
              ],
            },
          ],
        }).addMediaEntry(
          const MediaStoreEntry(
            id: 'photo',
            name: 'photo.png',
            kind: MediaStoreKind.image,
            source: {'kind': 'file', 'value': '/photo.png'},
          ),
        );
    expect(quickStartStep(document, exported: false), QuickStartStep.export);
    expect(quickStartStep(document, exported: true), QuickStartStep.complete);
  });
  testWidgets('guide waits without a Next button and disappears when complete', (tester) async {
    await tester.pumpWidget(
      OiApp(
        home: QuickStartHint(step: QuickStartStep.place, onDismiss: () {}),
      ),
    );
    expect(find.textContaining('Step 2 of 4'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
    await tester.pump(const Duration(seconds: 10));
    expect(find.textContaining('Step 2 of 4'), findsOneWidget);
    await tester.pumpWidget(
      OiApp(
        home: QuickStartHint(step: QuickStartStep.complete, onDismiss: () {}),
      ),
    );
    expect(find.textContaining('Step'), findsNothing);
  });
}
