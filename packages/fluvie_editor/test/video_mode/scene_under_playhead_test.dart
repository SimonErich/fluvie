import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': <Object?>[
    {
      'duration': '120f',
      'children': [
        {'id': 'el-a', 'type': 'Text', 'text': 'a'},
      ],
    },
    {
      'duration': '90f',
      'children': [
        {'id': 'el-b', 'type': 'Text', 'text': 'b'},
      ],
    },
  ],
};

void main() {
  testWidgets('builds with the scene under the playhead and follows boundary crossings', (
    tester,
  ) async {
    final timebase = VideoTimebase.of(EditorDocument.fromJson(_deck()));
    final transport = SlideTransport(fps: 30, length: timebase.totalFrames);
    addTearDown(transport.dispose);
    final builds = <int>[];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SceneUnderPlayhead(
          transport: transport,
          timebase: timebase,
          builder: (context, scene) {
            builds.add(scene);
            return Text('scene $scene');
          },
        ),
      ),
    );
    expect(find.text('scene 0'), findsOneWidget);

    // A seek inside the same scene does not rebuild the subtree.
    transport.seek(60);
    await tester.pump();
    expect(builds, [0]);

    // Crossing the boundary rebuilds with the incoming scene.
    transport.seek(150);
    await tester.pump();
    expect(find.text('scene 1'), findsOneWidget);
    expect(builds, [0, 1]);

    // And back.
    transport.seek(0);
    await tester.pump();
    expect(find.text('scene 0'), findsOneWidget);
    expect(builds, [0, 1, 0]);
  });

  testWidgets('a swapped transport or timebase re-reads the scene', (tester) async {
    final timebase = VideoTimebase.of(EditorDocument.fromJson(_deck()));
    final first = SlideTransport(fps: 30, length: timebase.totalFrames);
    final second = SlideTransport(fps: 30, length: timebase.totalFrames, initialFrame: 200);
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    Widget host(SlideTransport transport) => Directionality(
      textDirection: TextDirection.ltr,
      child: SceneUnderPlayhead(
        transport: transport,
        timebase: timebase,
        builder: (context, scene) => Text('scene $scene'),
      ),
    );
    await tester.pumpWidget(host(first));
    expect(find.text('scene 0'), findsOneWidget);
    await tester.pumpWidget(host(second));
    expect(find.text('scene 1'), findsOneWidget);
    // The retired transport's frames no longer drive the subtree.
    first.seek(0);
    await tester.pump();
    expect(find.text('scene 1'), findsOneWidget);
  });
}
