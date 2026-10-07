part of 'editor_performance.dart';

Future<void> _measureTimeline(
  WidgetTester tester,
  VideoLaneModel model,
  Map<String, Object?> results,
) async {
  final controller = TrackTimelineController();
  addTearDown(controller.dispose);
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    OiApp(
      home: SizedBox(
        height: 350,
        child: TrackTimeline(
          tracks: model.tracks,
          fps: 24,
          totalFrames: 4320,
          controller: controller,
        ),
      ),
    ),
  );
  final zoomFrames = await EditorFrameMetrics.start(tester);
  final zooms = <double>[];
  for (var i = 0; i < 20; i++) {
    final watch = Stopwatch()..start();
    controller.pixelsPerFrame = i.isEven ? 2 : 8;
    await tester.pump();
    watch.stop();
    zooms.add(watch.elapsedMicroseconds / 1000);
  }
  results['timelineZoomAndLayout'] = {
    ..._summary(zooms),
    'frames': await zoomFrames.finish(tester),
  };
  final scrollFrames = await EditorFrameMetrics.start(tester);
  final scroll = <double>[];
  for (var i = 0; i < 10; i++) {
    final watch = Stopwatch()..start();
    tester.binding.handlePointerEvent(
      PointerScrollEvent(
        position: tester.getCenter(find.byType(TrackTimeline)),
        scrollDelta: Offset(i.isEven ? 300 : -300, 0),
      ),
    );
    await tester.pump();
    watch.stop();
    scroll.add(watch.elapsedMicroseconds / 1000);
  }
  results['timelineScrollGestureAndLayout'] = {
    ..._summary(scroll),
    'frames': await scrollFrames.finish(tester),
  };
}

Future<void> _measureCanvas(
  WidgetTester tester,
  EditorDocument document,
  Map<String, Object?> results,
) async {
  final viewport = CanvasViewportController();
  final transport = SlideTransport(fps: 24, length: 4320);
  final history = DocumentHistory(document);
  addTearDown(history.dispose);
  addTearDown(transport.dispose);
  addTearDown(viewport.dispose);
  await tester.pumpWidget(
    ProviderScope(
      child: OiApp(
        home: ListenableBuilder(
          listenable: history,
          builder: (context, child) => EditorCanvas(
            document: history.document,
            slide: 0,
            interactive: true,
            wholeDocument: true,
            viewportController: viewport,
            transport: transport,
            fitMargin: 0,
            previewMaxEdge: 960,
            onCommand: history.dispatch,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  final canvasOrigin = tester.getTopLeft(find.byType(EditorCanvas));
  final start = canvasOrigin + viewport.toViewport(const Offset(1920, 1080));
  await tester.tapAt(start);
  await tester.pump();
  final gesture = await tester.startGesture(start);
  await tester.pump();
  final dragFrames = await EditorFrameMetrics.start(tester);
  final dragging = <double>[];
  for (var i = 0; i < 60; i++) {
    final watch = Stopwatch()..start();
    await gesture.moveBy(Offset(i.isEven ? 2 : -2, 1));
    await tester.pump();
    watch.stop();
    dragging.add(watch.elapsedMicroseconds / 1000);
  }
  await gesture.up();
  await tester.pump();
  expect(history.canUndo, isTrue);
  results['canvasDragUpdateAndLayout'] = {
    ..._summary(dragging),
    'frames': await dragFrames.finish(tester),
  };
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}
