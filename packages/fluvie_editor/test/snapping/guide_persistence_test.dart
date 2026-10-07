import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'children': [
        {'id': 'el-1', 'type': 'Text', 'text': 'one'},
      ],
    },
    {
      'duration': '30f',
      'children': [
        {'id': 'el-2', 'type': 'Box', 'color': '#6C5CE7'},
      ],
    },
  ],
};

const _guides = [
  ManualGuide(orientation: SnapOrientation.vertical, position: 0.25),
  ManualGuide(orientation: SnapOrientation.horizontal, position: 0.6),
];

void main() {
  test('manual guides round-trip through save and load', () {
    final doc = EditorDocument.fromJson(
      _deck(),
    ).setSceneMeta(1, {'guides': ManualGuide.listToJson(_guides)});

    // Save is toJson; simulate the file round-trip byte-for-byte.
    final saved = jsonEncode(doc.toJson());
    final loaded = EditorDocument.fromJson(jsonDecode(saved) as Map<String, Object?>);

    expect(ManualGuide.listFromJson(loaded.sceneMeta(1)['guides']), _guides);
    expect(ManualGuide.listFromJson(loaded.sceneMeta(0)['guides']), isEmpty);
    expect(loaded.renderDigest, EditorDocument.fromJson(_deck()).renderDigest);
  });

  test('SetSceneMetaCommand writes guides and undo removes them again', () {
    final history = DocumentHistory(EditorDocument.fromJson(_deck()))
      ..dispatch(SetSceneMetaCommand(index: 0, meta: {'guides': ManualGuide.listToJson(_guides)}));
    expect(ManualGuide.listFromJson(history.document.sceneMeta(0)['guides']), _guides);

    history.undo();
    expect(ManualGuide.listFromJson(history.document.sceneMeta(0)['guides']), isEmpty);
    history.redo();
    expect(ManualGuide.listFromJson(history.document.sceneMeta(0)['guides']), _guides);
  });

  test('a stream of guide drags coalesces through the merge group', () {
    final history = DocumentHistory(EditorDocument.fromJson(_deck()));
    for (final position in [0.2, 0.3, 0.4]) {
      history.dispatch(
        SetSceneMetaCommand(
          index: 0,
          meta: {
            'guides': ManualGuide.listToJson([
              ManualGuide(orientation: SnapOrientation.vertical, position: position),
            ]),
          },
          mergeGroup: 'guide-drag',
        ),
      );
    }
    expect(
      ManualGuide.listFromJson(history.document.sceneMeta(0)['guides']).single.position,
      0.4,
    );
    history.undo();
    expect(
      ManualGuide.listFromJson(history.document.sceneMeta(0)['guides']),
      isEmpty,
      reason: 'one drag is one undo step',
    );
  });
}
