import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/serialization/spec_validation.dart';
import 'package:fluvie/src/serialization/video_spec.dart';

Map<String, Object?> _spec({Map<String, Object?>? editor}) => {
  'fluvieSpec': 1,
  'size': 'square',
  'fps': 30,
  'scenes': [
    {
      'duration': '30f',
      'children': [
        {'id': 'el-1', 'type': 'Text', 'text': 'hello'},
      ],
    },
  ],
  'editor': ?editor,
};

Map<String, Object?> _editorBlock() => {
  'editorSchema': 1,
  'elements': {
    'el-1': {'name': 'Headline', 'locked': true},
  },
  'guides': [
    {'axis': 'x', 'at': 0.5},
  ],
};

void main() {
  group('the editor block', () {
    test('is preserved verbatim through fromJson and toJson', () {
      final spec = VideoSpec.fromJson(_spec(editor: _editorBlock()));
      expect(spec.editorData, _editorBlock());
      expect(spec.toJson()['editor'], _editorBlock());
    });

    test('is absent when the document has none', () {
      final spec = VideoSpec.fromJson(_spec());
      expect(spec.editorData, isNull);
      expect(spec.toJson().containsKey('editor'), isFalse);
    });

    test('never affects the render digest', () {
      final bare = VideoSpec.fromJson(_spec());
      final annotated = VideoSpec.fromJson(_spec(editor: _editorBlock()));
      expect(annotated.digest(), bare.digest());

      final renamed = _editorBlock();
      (renamed['elements']! as Map)['el-1'] = {'name': 'Retitled'};
      expect(VideoSpec.fromJson(_spec(editor: renamed)).digest(), bare.digest());
    });

    test('render-affecting keys still move the digest', () {
      final bare = VideoSpec.fromJson(_spec());
      final moved = _spec();
      final scene = (moved['scenes']! as List).first as Map<String, Object?>;
      final child = (scene['children']! as List).first as Map<String, Object?>;
      child['text'] = 'other';
      expect(VideoSpec.fromJson(moved).digest(), isNot(bare.digest()));
    });

    test('is a known key with an open interior', () {
      expect(unknownSpecProps(_spec(editor: _editorBlock())), isEmpty);
      final wild = _spec(
        editor: {
          'anything': {
            'nested': ['goes'],
          },
        },
      );
      expect(unknownSpecProps(wild), isEmpty);
    });
  });
}
