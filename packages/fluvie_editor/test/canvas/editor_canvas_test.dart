import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show LivePlaybackController;
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:fluvie_editor/src/canvas/slide_deriver.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart' show LiveScenePlayer;
import 'package:obers_ui/obers_ui.dart' show OiThemeData, OiThemeScope;

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '90f',
      'layout': 'canvas',
      'background': {'kind': 'color', 'color': '#14141C'},
      'children': [
        {
          'id': 'el-a',
          'type': 'Text',
          'text': 'parity',
          'transform': {'x': 0.5, 'y': 0.4},
          'style': {'color': '#F2F2F7', 'fontSize': 24},
          'animate': [
            {'preset': 'fadeIn', 'duration': '30f'},
          ],
        },
      ],
    },
  ],
};

Future<ui.Image> _snapshot(WidgetTester tester, Key key) async {
  final boundary = tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
  return tester.runAsync(boundary.toImage).then((image) => image!);
}

Future<List<int>> _bytes(WidgetTester tester, ui.Image image) async {
  final data = await tester.runAsync(() => image.toByteData());
  return data!.buffer.asUint8List();
}

void main() {
  testWidgets('the canvas held frame matches the presenter render byte for byte', (
    tester,
  ) async {
    final doc = EditorDocument.fromJson(_deck());
    const canvasKey = Key('editor-canvas');
    const presenterKey = Key('presenter-render');

    // The editor canvas, fitted 1:1 (viewport == slide size, no margin).
    await tester.pumpWidget(
      OiThemeScope(
        data: OiThemeData.dark(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              key: canvasKey,
              child: SizedBox(
                width: 320,
                height: 180,
                child: EditorCanvas(document: doc, slide: 0, fitMargin: 0),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    final canvasImage = await _snapshot(tester, canvasKey);
    final canvasBytes = await _bytes(tester, canvasImage);

    // The presenter's render of the same slide, held at the same frame
    // (the player holds at scene start on mount; seek after the pump).
    final derived = SlideDeriver().derive(doc, 0);
    final clock = LivePlaybackController(fps: 30);
    addTearDown(clock.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: presenterKey,
            child: SizedBox(
              width: 320,
              height: 180,
              child: LiveScenePlayer(
                video: doc.spec.build(),
                controller: clock,
                autoPlay: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    clock.hold(derived.settleFrame);
    await tester.pump();
    final presenterImage = await _snapshot(tester, presenterKey);
    final presenterBytes = await _bytes(tester, presenterImage);

    expect(canvasBytes, presenterBytes);
  });

  testWidgets('the canvas backdrop frames the slide when the viewport is larger', (
    tester,
  ) async {
    final doc = EditorDocument.fromJson(_deck());
    await tester.pumpWidget(
      OiThemeScope(
        data: OiThemeData.dark(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(width: 800, height: 600, child: EditorCanvas(document: doc, slide: 0)),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(EditorCanvas), findsOneWidget);
    expect(find.text('parity'), findsOneWidget);
  });

  testWidgets('a viewport resize refits the camera after the frame', (tester) async {
    final doc = EditorDocument.fromJson(_deck());
    final controller = CanvasViewportController();
    Widget host(double width) => OiThemeScope(
      data: OiThemeData.dark(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: width,
            height: 600,
            child: EditorCanvas(document: doc, slide: 0, viewportController: controller),
          ),
        ),
      ),
    );
    await tester.pumpWidget(host(800));
    await tester.pump();
    final before = controller.scale;
    await tester.pumpWidget(host(400));
    await tester.pump();
    await tester.pump();
    expect(controller.scale, lessThan(before));
  });
}
