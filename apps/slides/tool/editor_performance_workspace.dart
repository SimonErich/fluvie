import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:slides/editor/editor_screen.dart';

import '../test/memory_autosave_store.dart';
import 'editor_performance_metrics.dart';

/// Measures the actual application host, including its history listeners,
/// inspector, timeline, filmstrips and preview. No persistent user state is used.
Future<Map<String, Object>> measureEditorWorkspace(
  WidgetTester tester,
  EditorDocument document,
) async {
  await tester.pumpWidget(
    OiApp(
      home: EditorScreen(
        document: document,
        title: 'Performance acceptance',
        onClose: () {},
        autosave: MemoryAutosaveStore(),
      ),
    ),
  );
  final canvasFinder = find.byType(EditorCanvas);
  bool decoded() => tester
      .widgetList<RawImage>(find.descendant(of: canvasFinder, matching: find.byType(RawImage)))
      .any((image) => image.image != null);
  final deadline = DateTime.now().add(const Duration(seconds: 90));
  while (!decoded() && DateTime.now().isBefore(deadline)) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
  }
  expect(decoded(), isTrue, reason: 'The full editor must display a decoded video frame');
  final timeline = tester.widget<TrackTimeline>(find.byType(TrackTimeline));
  final controller = timeline.controller!;
  final zoom = await EditorFrameMetrics.start(tester);
  for (var i = 0; i < 30; i++) {
    controller.pixelsPerFrame = i.isEven ? 2 : 8;
    await tester.pump();
  }
  final result = <String, Object>{
    'scenario': {
      'readiness': 'First decoded canvas image; filmstrip/background work may still be cold.',
      'interactionOrder': ['timelineZoom', 'timelineScroll', 'canvasDrag', 'canvasDragCommit'],
      'canvasDragUpdates': 120,
      'timingBatchFlushMs': 1100,
      'pauseBetweenDragAndCommit': false,
    },
    'timelineZoom': await zoom.finish(tester),
  };
  final scroll = await EditorFrameMetrics.start(tester);
  for (var i = 0; i < 20; i++) {
    tester.binding.handlePointerEvent(
      PointerScrollEvent(
        position: tester.getCenter(find.byType(TrackTimeline)),
        scrollDelta: Offset(i.isEven ? 300 : -300, 0),
      ),
    );
    await tester.pump();
  }
  result['timelineScroll'] = await scroll.finish(tester);
  expect(
    tester.widget<EditorCanvas>(canvasFinder).document.documentDigest,
    document.documentDigest,
  );
  final viewport = tester.widget<CanvasViewport>(
    find.descendant(of: canvasFinder, matching: find.byType(CanvasViewport)),
  );
  final start =
      tester.getTopLeft(canvasFinder) +
      viewport.controller.toViewport(
        const Offset(1920, 1080),
      );
  await tester.tapAt(start);
  await tester.pump();
  final gesture = await tester.startGesture(start);
  await tester.pump();
  final drag = await EditorFrameMetrics.start(tester);
  for (var i = 0; i < 120; i++) {
    await gesture.moveBy(Offset(i.isEven ? 1 : -1, i < 60 ? 0.5 : -0.25));
    await tester.pump();
  }
  final lastDragFrame = tester.binding.platformDispatcher.frameData.frameNumber;
  await gesture.up();
  await tester.pump();
  final dragFrames = await drag.finishSplit(tester, lastBeforeFrame: lastDragFrame);
  result['canvasDrag'] = dragFrames.before;
  result['canvasDragCommit'] = dragFrames.after;
  final edited = tester.widget<EditorCanvas>(canvasFinder).document;
  expect(edited.renderDigest, isNot(document.renderDigest));
  await tester.tap(
    find.byWidgetPredicate(
      (widget) => widget is OiIconButton && widget.semanticLabel == 'Undo',
    ),
  );
  await tester.pump();
  expect(
    tester.widget<EditorCanvas>(canvasFinder).document.documentDigest,
    document.documentDigest,
  );
  result['dragUndoRestoresDocument'] = true;
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  expect(tester.takeException(), isNull);
  return result;
}
