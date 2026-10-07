part of 'editor_e2e_test.dart';

void _registerEffectsJourney() {
  // Journey V5 — the Effects tab drops a glow on an element, keyframes its
  // intensity with the diamond, and the document carries the keyframed
  // stack — which is exactly what a save or an export would write.
  testWidgets('the Effects tab stacks and keyframes a glow the document keeps', (tester) async {
    const deck =
        '{"fluvieSpec": 1, "size": {"width": 320, "height": 180}, "fps": 30, '
        '"scenes": [{"duration": "60f", "layout": "canvas", '
        '"background": {"kind": "color", "color": "#14141C"}, '
        '"children": [{"id": "el-hero", "type": "Box", "color": "#6C5CE7", '
        '"transform": {"x": 0.5, "y": 0.5, "w": 0.4, "h": 0.4}}]}]}';

    useDesktopSurface(tester);
    await tester.pumpWidget(
      SlidesApp(
        openFile: () async => parseFluvieJson('glow.fluvie', deck),
        saver: NeverSaver(),
        recents: MemoryRecents(),
        autosave: MemoryAutosaveStore(),
        startPrefs: MemoryStartPrefsStore(const StartPrefs(tipsDismissed: true)),
      ),
    );
    await tester.pumpAndSettle();
    await openDeckForEdit(tester);
    await tester.pumpAndSettle();

    // Select the hero and stack a bloom on it from the Effects browser.
    await tester.tapAt(tester.getCenter(find.byType(EditorCanvas)));
    await tester.pump();
    await tester.tap(find.text('Effects'));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('effect-chip-bloom')));
    await tester.tap(find.byKey(const ValueKey('effect-chip-bloom')));
    await tester.pump();

    // The diamond keyframes the amount over the element's window.
    await tester.ensureVisible(find.byKey(const ValueKey('effect-stopwatch-0-amount')));
    await tester.tap(find.byKey(const ValueKey('effect-stopwatch-0-amount')));
    await tester.pump();

    // The document — what a save or export writes — carries the stack.
    final document = tester.widget<EditorCanvas>(find.byType(EditorCanvas)).document;
    final effects = document.elementJson('el-hero')!['effects']! as List;
    final bloom = (effects.single! as Map).cast<String, Object?>();
    expect(bloom['kind'], 'bloom');
    final amount = (bloom['amount']! as Map).cast<String, Object?>();
    expect(amount['values'], [0.4, 0.4]);
    expect(amount['positions'], ['0f', '60f']);
  });
}
