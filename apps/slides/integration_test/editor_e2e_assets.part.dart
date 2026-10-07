part of 'editor_e2e_test.dart';

void _registerAssetsJourney() {
  // Journey 3 — the assets panel imports a new file (fake importer, no OS
  // dialog) into the reusable media store. Audio fixtures keep the real
  // embedder off the disk (an image source would resolve a missing file).
  testWidgets('the assets panel imports a new file into the reusable media store', (tester) async {
    Map<String, Object?> deck() => {
      'fluvieSpec': 1,
      'size': {'width': 320, 'height': 180},
      'fps': 30,
      'editor': {
        'media': [
          {
            'id': 'media-bed',
            'name': 'bed.mp3',
            'kind': 'audio',
            'source': {'kind': 'file', 'value': '/media/bed.mp3'},
          },
        ],
      },
      'scenes': [
        {
          'duration': '60f',
          'layout': 'canvas',
          'children': [
            {
              'id': 'el-box',
              'type': 'Box',
              'color': '#6C5CE7',
              'transform': {'x': 0.5, 'y': 0.5, 'w': 0.3, 'h': 0.3},
            },
          ],
        },
      ],
    };

    useDesktopSurface(tester);
    const pick = MediaPick(
      source: {'kind': 'file', 'value': '/media/added.mp3'},
      isVideo: false,
      isAudio: true,
      name: 'added.mp3',
      sizeBytes: 3,
    );
    await tester.pumpWidget(
      OiApp(
        title: 'test',
        theme: OiThemeData.dark(),
        home: EditorScreen(
          document: EditorDocument.fromJson(deck()),
          title: 'mine.fluvie',
          onClose: () {},
          saver: NeverSaver(),
          importer: PickImporter(pick),
          autosave: MemoryAutosaveStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_document(tester).mediaEntries, hasLength(1));

    await tester.tap(find.bySemanticsLabel('Deck assets'));
    await tester.pumpAndSettle();
    expect(find.text('bed.mp3'), findsOneWidget);
    expect(find.text('Import media'), findsOneWidget);

    // Import through the fake importer: a fresh entry lands in the store.
    await tester.tap(find.text('Import media'));
    await tester.pumpAndSettle();
    final entries = _document(tester).mediaEntries;
    expect(entries, hasLength(2));
    expect(entries.any((entry) => entry.name == 'added.mp3'), isTrue);

    // Reopening the panel shows both assets, so the import is reusable.
    await tester.tap(find.bySemanticsLabel('Deck assets'));
    await tester.pumpAndSettle();
    expect(find.text('bed.mp3'), findsOneWidget);
    expect(find.text('added.mp3'), findsOneWidget);
  });
}
