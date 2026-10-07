import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show LivePlayer;
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData;

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '120f',
      'children': [
        {
          'id': 'el-a',
          'type': 'Text',
          'text': 'a',
          'animate': [
            {'preset': 'fadeIn', 'duration': '30f'},
          ],
        },
      ],
    },
    {
      'duration': '90f',
      'children': [
        {
          'id': 'el-b',
          'type': 'Text',
          'text': 'b',
          'animate': [
            {'preset': 'fadeIn', 'duration': '15f'},
          ],
        },
      ],
    },
  ],
};

Future<void> _pump(
  WidgetTester tester,
  EditorDocument document,
  SlideTransport transport, {
  int slide = 0,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: OiApp(
        title: 'test',
        theme: OiThemeData.dark(),
        home: Column(
          children: [
            Expanded(
              child: EditorCanvas(
                document: document,
                slide: slide,
                fitMargin: 0,
                transport: transport,
              ),
            ),
            SizedBox(
              width: 640,
              child: TimelinePanel(
                document: document,
                slide: slide,
                transport: transport,
                onCommand: (_) {},
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('scrub to frame N: the canvas clock and the ruler both report N', (tester) async {
    final document = EditorDocument.fromJson(_deck());
    final derived = SlideDeriver().derive(document, 0);
    final transport = SlideTransport(
      fps: 30,
      length: derived.totalFrames,
      initialFrame: derived.settleFrame,
    );
    addTearDown(transport.dispose);
    await _pump(tester, document, transport);

    // Scrub the ruler to x = +100px of the lanes = frame 25 at 4 px/frame.
    final ruler = tester.getTopLeft(find.byType(TrackTimeline)) + const Offset(140, 12);
    final gesture = await tester.startGesture(
      ruler + const Offset(80, 0),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(transport.frame, 25);
    final player = tester.widget<LivePlayer>(find.byType(LivePlayer));
    expect(player.controller.frame, 25);
    expect(tester.widget<TrackTimeline>(find.byType(TrackTimeline)).playhead, 25);
  });

  testWidgets('playing keeps the stage and the ruler in lockstep per frame', (tester) async {
    final document = EditorDocument.fromJson(_deck());
    final transport = SlideTransport(fps: 30, length: 120);
    addTearDown(transport.dispose);
    await _pump(tester, document, transport);

    transport.play();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(transport.frame, 15);
    final player = tester.widget<LivePlayer>(find.byType(LivePlayer));
    expect(player.controller.frame, 15);
    expect(tester.widget<TrackTimeline>(find.byType(TrackTimeline)).playhead, 15);
    transport.pause();
  });

  testWidgets('a slide switch swaps the transport; the stage follows the new clock', (
    tester,
  ) async {
    final document = EditorDocument.fromJson(_deck());
    final deriver = SlideDeriver();
    final first = SlideTransport(
      fps: 30,
      length: deriver.derive(document, 0).totalFrames,
      initialFrame: deriver.derive(document, 0).settleFrame,
    );
    await _pump(tester, document, first);
    expect(
      identical(
        tester.widget<LivePlayer>(find.byType(LivePlayer)).controller,
        first.controller,
      ),
      isTrue,
    );

    final derived = deriver.derive(document, 1);
    final second = SlideTransport(
      fps: 30,
      length: derived.totalFrames,
      initialFrame: derived.settleFrame,
    );
    addTearDown(second.dispose);
    first.dispose();
    await _pump(tester, document, second, slide: 1);
    expect(
      identical(
        tester.widget<LivePlayer>(find.byType(LivePlayer)).controller,
        second.controller,
      ),
      isTrue,
    );
    expect(second.frame, derived.settleFrame);
    expect(
      tester.widget<TrackTimeline>(find.byType(TrackTimeline)).playhead,
      derived.settleFrame.toDouble(),
    );
    // The retired transport is gone for good.
    expect(() => first.addListener(() {}), throwsFlutterError);
  });
}
