part of 'editor_e2e_test.dart';

void _registerExportJourneys() {
  // Journey 5 — Export writes real artifacts through faked save seams.
  group('Export writes real artifacts', () {
    Map<String, Object?> deck() => {
      'fluvieSpec': 1,
      'size': {'width': 320, 'height': 180},
      'fps': 30,
      'scenes': [
        {
          'duration': '60f',
          'layout': 'canvas',
          'background': {'kind': 'color', 'color': '#14141C'},
          'children': [
            {
              'id': 'el-box',
              'type': 'Box',
              'color': '#6C5CE7',
              'transform': {'x': 0.5, 'y': 0.5, 'w': 0.4, 'h': 0.4},
            },
          ],
        },
        {
          'duration': '30f',
          'children': [
            {'id': 'el-text', 'type': 'Text', 'text': 'the second slide'},
          ],
        },
      ],
    };

    // Pump widget frames and drain real async work until [done] — the export
    // interleaves hidden render frames with engine read-backs.
    Future<void> drain(WidgetTester tester, bool Function() done) async {
      for (var i = 0; i < 120 && !done(); i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      }
      await tester.pump();
    }

    Future<({RecordingSaver saver, RecordingImageExporter images})> pump(
      WidgetTester tester,
    ) async {
      useDesktopSurface(tester);
      final saver = RecordingSaver();
      final images = RecordingImageExporter();
      await tester.pumpWidget(
        OiApp(
          title: 'test',
          theme: OiThemeData.dark(),
          home: EditorScreen(
            document: EditorDocument.fromJson(deck()),
            title: 'mine.fluvie',
            onClose: () {},
            saver: saver,
            images: images,
            render: UnavailableRenderService(),
            autosave: MemoryAutosaveStore(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (saver: saver, images: images);
    }

    testWidgets('Export PDF writes one real page per slide', (tester) async {
      final harness = await pump(tester);
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export PDF'));
      await drain(tester, () => harness.saver.bytesCalls.isNotEmpty);

      final call = harness.saver.bytesCalls.single;
      expect(call.name, 'mine.pdf');
      final text = latin1.decode(call.bytes);
      expect(text.startsWith('%PDF'), isTrue, reason: 'a real PDF leads with its magic');
      expect(RegExp(r'/Count (\d+)').firstMatch(text)?.group(1), '2', reason: 'one page per slide');
    });

    testWidgets('Export slide images writes one real PNG per slide', (tester) async {
      final harness = await pump(tester);
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export slide images (PNG)'));
      await drain(tester, () => harness.images.saved.isNotEmpty);

      final call = harness.images.saved.single;
      expect(call.baseName, 'mine');
      expect(call.images, hasLength(2));
      for (final png in call.images) {
        // Every artifact is a real PNG: the 8-byte signature leads.
        expect(png.sublist(0, 8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      }
    });
  });
}
