part of 'editor_e2e_test.dart';

void _registerGeometryJourney() {
  // Journey 2 — the geometry regression: video mode edits a later scene at its
  // settled frame, where the editor geometry matches the compositor's render.
  testWidgets('video mode edits a later scene at its settled frame, geometry == render', (
    tester,
  ) async {
    // Scene 1 arrives on a 15-frame `slide` entrance: its span starts at 45
    // (mid-blend) while it settles at 60 — the shape that produced the
    // "X = -52.3" corruption. Each scene carries one identifiable Box.
    const deck =
        '{"fluvieSpec": 1, "size": {"width": 320, "height": 180}, "fps": 30, '
        '"scenes": [ '
        '{"duration": "60f", "layout": "canvas", '
        '"background": {"kind": "color", "color": "#14141C"}, '
        '"children": [{"id": "el-one", "type": "Box", "color": "#6C5CE7", '
        '"transform": {"x": 0.5, "y": 0.5, "w": 0.3, "h": 0.3}}]}, '
        '{"duration": "60f", "layout": "canvas", '
        '"enter": {"kind": "slide", "duration": "15f"}, '
        '"background": {"kind": "color", "color": "#101820"}, '
        '"children": [{"id": "el-two", "type": "Box", "color": "#00B894", '
        '"transform": {"x": 0.4, "y": 0.6, "w": 0.3, "h": 0.3}}]}]}';
    EditorCanvas canvas() => tester.widget<EditorCanvas>(find.byType(EditorCanvas));
    Finder placed(String id) => find.descendant(
      of: find.byType(EditorCanvas),
      matching: find.byWidgetPredicate((widget) => widget is Placed && widget.id == id),
    );
    // The Placed wrapper spans the whole canvas; the element's own Box renders
    // at the placed rect, so its center is the true on-screen position.
    Finder box(String id) => find.descendant(of: placed(id), matching: find.byType(Box));

    useDesktopSurface(tester);
    await tester.pumpWidget(
      SlidesApp(
        openFile: () async => parseFluvieJson('transition.fluvie', deck),
        saver: NeverSaver(),
        recents: MemoryRecents(),
        autosave: MemoryAutosaveStore(),
        startPrefs: MemoryStartPrefsStore(const StartPrefs(tipsDismissed: true)),
      ),
    );
    await tester.pumpAndSettle();
    await openDeckForEdit(tester);
    await tester.pumpAndSettle();

    // Toggle into video mode, then step to the later scene.
    await tester.tap(find.bySemanticsLabel('Video mode'));
    await tester.pumpAndSettle();
    expect(canvas().wholeDocument, isTrue);
    await tester.tap(find.bySemanticsLabel('Next slide'));
    await tester.pumpAndSettle();

    final transport = canvas().transport!;
    final timebase = VideoTimebase.of(canvas().document);
    final settle = timebase.settleFrameOf(1);
    final spanStart = timebase.sceneSpans[1].start;

    // (a) The seek parked on the SETTLED frame, past the incoming blend —
    // never at the span start, where the scene is still displaced.
    expect(settle, greaterThan(spanStart), reason: 'the fixture must have a real blend window');
    expect(transport.frame, settle);
    expect(transport.frame, isNot(spanStart));
    expect(canvas().slide, 1);
    expect(canvas().settleFrame, settle);

    // Geometry == render: the Box renders where its authored transform says,
    // and the canvas map agrees to the pixel. Parked mid-transition, the
    // render would be offset from the geometry the gizmo grabs.
    expect(box('el-two'), findsOneWidget);
    final rendered = tester.getCenter(box('el-two'));
    final expected = canvasAt(tester, const Offset(0.4 * 320, 0.6 * 180));
    expect(
      (rendered - expected).distance,
      lessThan(1.5),
      reason: 'the settled render sits exactly where the editor geometry places it',
    );
    expect(placed('el-one'), findsNothing);

    Map<String, Object?> transformOf(String id) =>
        canvas().document.elementJson(id)!['transform']! as Map<String, Object?>;
    final before = transformOf('el-two');
    expect(before['x'], 0.4);
    expect(before['y'], 0.6);

    // (b) Drag the element by grabbing it exactly where it renders. The scene
    // is settled, so the hit-test finds it and the drag commits a sane
    // placement — the corrupt negative X must NOT reappear.
    final gesture = await tester.startGesture(rendered);
    await tester.pump(const Duration(milliseconds: 30));
    await gesture.moveBy(const Offset(28, 16));
    await tester.pump();
    await gesture.moveBy(const Offset(12, 8));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final after = transformOf('el-two');
    final x = after['x']! as double;
    final y = after['y']! as double;
    expect(x, greaterThan(before['x']! as double), reason: 'the rightward drag increased X');
    expect(y, greaterThan(before['y']! as double), reason: 'the downward drag increased Y');
    expect(x, inInclusiveRange(0.0, 1.0), reason: 'X stays an on-canvas fraction, never "-52.3"');
    expect(y, inInclusiveRange(0.0, 1.0), reason: 'Y stays an on-canvas fraction');

    final movedRender = tester.getCenter(box('el-two'));
    expect(movedRender.dx, greaterThan(rendered.dx));
    expect(movedRender.dy, greaterThan(rendered.dy));
  });
}
