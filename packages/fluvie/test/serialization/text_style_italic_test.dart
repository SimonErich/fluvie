import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' as fv;
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/serialization/codecs/text_style_codec.dart';

void main() {
  test('italic captions pass the strict render-path schema', () {
    final document = <String, Object?>{
      'fluvieSpec': 1,
      'scenes': [
        {
          'duration': '60f',
          'children': [
            {
              'type': 'Text',
              'text': 'Together',
              'style': {'fontFamily': 'Newsreader', 'fontStyle': 'italic'},
            },
          ],
        },
      ],
    };
    fv.assertNoUnknownSpecProps(document);
    expect(fv.VideoSpec.fromJson(document).build().totalFrames, 60);
  });
  test('italic and normal survive spec round trips', () {
    for (final style in FontStyle.values) {
      final original = TextStyle(fontFamily: 'Newsreader', fontStyle: style, fontSize: 22);
      expect(decodeTextStyle(encodeTextStyle(original)), original);
    }
  });
  test('unknown font style is rejected with its field path', () {
    expect(
      () => decodeTextStyle({'fontStyle': 'oblique'}, path: ['caption', 'style']),
      throwsA(
        isA<FluvieSpecError>().having((e) => e.path, 'path', ['caption', 'style', 'fontStyle']),
      ),
    );
  });
}
