import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart';

void main() {
  const entry = MediaStoreEntry(
    id: 'one',
    name: 'clip.mp4',
    kind: MediaStoreKind.video,
    source: {'kind': 'file', 'value': '/clip.mp4'},
    duration: '2s',
    fps: 24,
    inFrames: 6,
    outFrames: 30,
  );
  testWidgets('source I and O mark the source playhead while its monitor has focus', (
    tester,
  ) async {
    final marked = <MediaStoreEntry>[];
    await tester.pumpWidget(
      OiApp(
        home: Align(
          child: SizedBox(
            width: 400,
            child: SourceMonitor(entry: entry, onMarked: marked.add),
          ),
        ),
      ),
    );
    await tester.tap(find.text('clip.mp4'));
    tester.widget<OiSlider>(find.byType(OiSlider)).onChanged!.call(18);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    expect(marked.last.inFrames, 18);
    tester.widget<OiSlider>(find.byType(OiSlider)).onChanged!.call(36);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
    expect(marked.last.outFrames, 36);
  });
  testWidgets('source scrub drives the preview without changing saved marks', (tester) async {
    final marked = <MediaStoreEntry>[];
    await tester.pumpWidget(
      OiApp(
        home: Align(
          child: SizedBox(
            width: 400,
            child: SourceMonitor(
              entry: entry,
              onMarked: marked.add,
              previewBuilder: (context, asset, frame) => Text('source $frame'),
            ),
          ),
        ),
      ),
    );
    expect(find.text('source 0'), findsOneWidget);
    tester.widget<OiSlider>(find.byType(OiSlider)).onChanged?.call(12);
    await tester.pump();
    expect(find.text('source 12'), findsOneWidget);
    expect(marked, isEmpty);
  });
  testWidgets('bin drag carries source marks and selecting offers folder edits', (tester) async {
    final updates = <MediaStoreEntry>[];
    await tester.pumpWidget(
      OiApp(
        home: Align(
          child: SizedBox(
            width: 400,
            height: 700,
            child: MediaBinPanel(entries: const [entry], onEntryChanged: updates.add),
          ),
        ),
      ),
    );
    final drag = tester.widget<Draggable<SourceMonitorPlacement>>(
      find.byType(Draggable<SourceMonitorPlacement>),
    );
    expect(drag.data, (entry: entry, start: 6, end: 30));
    await tester.tap(find.text('clip.mp4'));
    await tester.pump();
    expect(find.text('Folder'), findsOneWidget);
  });
}
