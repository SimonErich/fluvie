// The bin panel. It holds no copy of the store: the listing is recomputed from
// the entries and the live query every build, so it can never show media the
// document no longer has.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart';

MediaStoreEntry _entry(
  String id,
  String name, {
  String? folder,
  String? duration,
  double? fps,
  int? width,
  int? height,
}) => MediaStoreEntry(
  id: id,
  name: name,
  kind: MediaStoreKind.video,
  source: {'kind': 'file', 'value': '/media/$name'},
  folder: folder,
  duration: duration,
  fps: fps,
  width: width,
  height: height,
);

final List<MediaStoreEntry> _entries = [
  _entry('m1', 'b-roll.mp4', folder: 'broll', duration: '4s', fps: 30, width: 1920, height: 1080),
  _entry('m2', 'Interview.mov', folder: 'interviews', duration: '12s', fps: 25),
  _entry('m3', 'logo-shot.mp4'),
];

Future<List<MediaStoreEntry>> _pump(
  WidgetTester tester, {
  List<MediaStoreEntry>? entries,
  VoidCallback? onImport,
}) async {
  final changed = <MediaStoreEntry>[];
  await tester.pumpWidget(
    OiApp(
      home: SizedBox(
        width: 340,
        height: 700,
        child: MediaBinPanel(
          entries: entries ?? _entries,
          onEntryChanged: changed.add,
          onImport: onImport,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return changed;
}

void main() {
  testWidgets('lists every entry in import order', (tester) async {
    await _pump(tester);

    for (final entry in _entries) {
      expect(find.text(entry.name), findsOneWidget);
    }
  });

  testWidgets('shows the probed facts, and nothing where none were probed', (tester) async {
    await _pump(tester);

    // A zero here would read as a fact, so an unprobed file says nothing.
    expect(MediaBinRow.detailFor(_entries[2]), isEmpty);
    expect(find.text('4s · 1920x1080 · 30fps · broll'), findsOneWidget);
  });

  testWidgets('a folder chip narrows the listing', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('broll'));
    await tester.pumpAndSettle();

    expect(find.text('b-roll.mp4'), findsOneWidget);
    expect(find.text('Interview.mov'), findsNothing);
  });

  testWidgets('All goes back to every folder', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('broll'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    expect(find.text('Interview.mov'), findsOneWidget);
  });

  testWidgets('searching narrows, and says so when nothing matches', (tester) async {
    await _pump(tester);

    await tester.enterText(find.byType(EditableText).first, 'interview');
    await tester.pumpAndSettle();
    expect(find.text('Interview.mov'), findsOneWidget);
    expect(find.text('b-roll.mp4'), findsNothing);

    await tester.enterText(find.byType(EditableText).first, 'zzzz');
    await tester.pumpAndSettle();
    expect(find.text('Nothing here matches that.'), findsOneWidget);
  });

  testWidgets('an empty bin invites an import rather than showing nothing', (tester) async {
    await _pump(tester, entries: const []);

    expect(find.text('Import a file to start building the deck.'), findsOneWidget);
  });

  testWidgets('the import action appears only where the host offers one', (tester) async {
    await _pump(tester);
    expect(find.text('Import media'), findsNothing);

    var imported = 0;
    await _pump(tester, onImport: () => imported++);
    expect(find.text('Import media'), findsOneWidget);

    await tester.tap(find.text('Import media'));
    await tester.pumpAndSettle();
    expect(imported, 1);
  });

  testWidgets('no folders means no folder row at all', (tester) async {
    await _pump(tester, entries: [_entry('m1', 'a.mp4')]);

    expect(find.text('All'), findsNothing);
  });

  testWidgets('selecting a row opens the monitor on it', (tester) async {
    await _pump(tester);

    expect(find.byType(SourceMonitor), findsNothing, reason: 'nothing is selected yet');

    await tester.tap(find.text('b-roll.mp4'));
    await tester.pumpAndSettle();

    expect(find.byType(SourceMonitor), findsOneWidget);
    expect(find.text('Mark in'), findsOneWidget);
  });

  testWidgets('a mark made in the monitor is reported for the document', (tester) async {
    final changed = await _pump(tester);

    await tester.tap(find.text('b-roll.mp4'));
    await tester.pumpAndSettle();
    // The monitor scrolls when the panel is short, so the action may be below
    // the fold — which is the behaviour, not a problem.
    await tester.ensureVisible(find.text('Mark in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark in'));
    await tester.pumpAndSettle();

    expect(changed.single.id, 'm1');
    expect(changed.single.inFrames, 0);
  });

  testWidgets('the monitor follows the store, not a copy of it', (tester) async {
    // The panel re-reads the selected entry every build, so an edit that lands
    // in the document is what the monitor shows next frame.
    await _pump(tester);
    await tester.tap(find.text('b-roll.mp4'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      OiApp(
        home: SizedBox(
          width: 340,
          height: 700,
          child: MediaBinPanel(
            entries: [
              _entries.first.copyWith(inFrames: 30, outFrames: 90),
              ..._entries.skip(1),
            ],
            onEntryChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('00:00:01:00 - 00:00:03:00'), findsOneWidget);
  });
}
