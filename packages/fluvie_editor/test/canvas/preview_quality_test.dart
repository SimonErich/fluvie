import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show PreviewMediaScope, Video, walkSceneTree;
import 'package:fluvie/src/animation/runtime/effect_stack.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart';

List<EffectStack> effectsOf(Video video) {
  final stacks = <EffectStack>[];
  walkSceneTree(video.scenes, overlays: video.overlays, (widget) {
    if (widget is EffectStack) stacks.add(widget);
  });
  return stacks;
}

void main() {
  testWidgets('draft removes nested and overlay grades only from the preview copy', (tester) async {
    final document = EditorDocument.fromJson(const {
      'fluvieSpec': 1,
      'size': {'width': 320, 'height': 180},
      'scenes': [
        {
          'duration': '2s',
          'children': [
            {
              'type': 'Group',
              'children': [
                {
                  'type': 'Box',
                  'color': '#123456',
                  'effects': [
                    {'kind': 'grade', 'exposure': 1.0},
                  ],
                },
              ],
            },
          ],
        },
      ],
      'overlays': [
        {
          'type': 'Box',
          'id': 'overlay',
          'color': '#654321',
          'effects': [
            {'kind': 'grade', 'contrast': 1.2},
          ],
        },
      ],
    });
    final original = document.toJson();
    final digest = document.renderDigest;
    final transport = SlideTransport(fps: 30, length: 60);
    addTearDown(transport.dispose);
    Widget canvas({required bool draft}) => OiApp(
      home: EditorCanvas(
        document: document,
        slide: 0,
        wholeDocument: true,
        transport: transport,
        bypassEffects: draft,
        previewMaxEdge: 80,
      ),
    );
    await tester.pumpWidget(canvas(draft: true));
    await tester.pump();
    final draft =
        tester.widget<PreviewMediaScope>(find.byType(PreviewMediaScope)).composition as Video;
    expect(effectsOf(draft), isEmpty);
    await tester.pumpWidget(canvas(draft: true));
    expect(
      tester.widget<PreviewMediaScope>(find.byType(PreviewMediaScope)).composition,
      same(draft),
    );
    await tester.pumpWidget(canvas(draft: false));
    final full =
        tester.widget<PreviewMediaScope>(find.byType(PreviewMediaScope)).composition as Video;
    expect(effectsOf(full), hasLength(2));
    expect(document.renderDigest, digest);
    expect(document.toJson(), original);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
