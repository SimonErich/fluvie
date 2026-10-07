part of 'editor_e2e_test.dart';

void _registerThemeJourney() {
  // Journey 4 — applying a builtin theme restyles the document.
  testWidgets('applying a builtin theme restyles the document', (tester) async {
    const deck =
        '{"fluvieSpec": 1, "size": {"width": 320, "height": 180}, "fps": 30, '
        '"scenes": [{"duration": "60f", "children": [{"type": "Text", "text": "hi", '
        '"style": {"color": "#FFFFFF", "fontSize": 40}}]}]}';
    useDesktopSurface(tester);
    await tester.pumpWidget(
      SlidesApp(
        openFile: () async => parseFluvieJson('deck.fluvie', deck),
        saver: NeverSaver(),
        recents: MemoryRecents(),
        autosave: MemoryAutosaveStore(),
        startPrefs: MemoryStartPrefsStore(const StartPrefs(tipsDismissed: true)),
      ),
    );
    await tester.pumpAndSettle();
    await openDeckForEdit(tester);
    await tester.pumpAndSettle();

    final before = _document(tester).renderDigest;
    expect(
      (_document(tester).toJson()['theme'] as Map?)?.containsKey('palette') ?? false,
      isFalse,
      reason: 'the plain deck starts without a palette',
    );

    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();
    expect(find.byType(ThemePanel), findsOneWidget);
    await tester.tap(find.text('midnight'));
    await tester.pumpAndSettle();

    final after = _document(tester);
    expect(
      (after.toJson()['theme']! as Map).containsKey('palette'),
      isTrue,
      reason: 'the builtin applied a palette to the deck theme',
    );
    expect(after.renderDigest, isNot(before), reason: 'the restyle moved the render digest');
  });
}
