part of 'editor_e2e_test.dart';

void _registerAuthoringJourney() {
  // Journey 1 — author from nothing, style, grow, present, and return.
  testWidgets('authoring a blank deck, presenting it, and returning intact', (tester) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(
      SlidesApp(
        saver: NeverSaver(),
        recents: MemoryRecents(),
        autosave: MemoryAutosaveStore(),
        startPrefs: MemoryStartPrefsStore(const StartPrefs(tipsDismissed: true)),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.text('New deck'));
    await tester.tap(find.text('New deck'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(EditorCanvas), findsOneWidget);

    // Press T, then click the HD canvas to drop a text element.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await tester.pump();
    await tester.tapAt(canvasAt(tester, const Offset(960, 400), size: const Size(1920, 1080)));
    await tester.pump();
    await tester.enterText(find.byType(EditableText).first, 'Built from nothing');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    final id = _document(tester).elementIdsInScene(0).single;
    expect(_document(tester).elementJson(id)!['text'], 'Built from nothing');

    // Change the font size through the inspector (still selected after insert).
    final sizeField = find.descendant(
      of: find.byType(EditorInspector),
      matching: find.byWidgetPredicate(
        (widget) => widget is EditableText && widget.controller.text == '32',
      ),
    );
    expect(sizeField, findsOneWidget);
    await tester.enterText(sizeField, '72');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(
      (_document(tester).elementJson(id)!['style']! as Map<String, Object?>)['fontSize'],
      72.0,
    );

    // Grow the deck: Add slide, then Duplicate slide -> three scenes.
    await tester.tap(find.bySemanticsLabel('Add slide'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Duplicate slide'));
    await tester.pump();
    expect(_document(tester).sceneCount, 3);

    // Present: the real presenter mounts and shows the authored headline.
    await tester.tap(find.text('Present'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(FluvieSlides), findsOneWidget);
    expect(
      find.descendant(of: find.byType(FluvieSlides), matching: find.text('Built from nothing')),
      findsOneWidget,
    );

    // Close the presenter and land back in the editor, deck intact.
    await tester.tap(
      find.descendant(
        of: find.byType(FluvieSlides),
        matching: find.byWidgetPredicate(
          (widget) => widget is OiIconButton && widget.icon == OiIcons.x,
        ),
      ),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(find.byType(FluvieSlides), findsNothing);
    expect(find.byType(EditorScreen), findsOneWidget);
    expect(_document(tester).sceneCount, 3);
    expect(_document(tester).elementJson(id)!['text'], 'Built from nothing');
  });
}
