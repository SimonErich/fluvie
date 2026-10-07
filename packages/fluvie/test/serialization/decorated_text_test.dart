import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show FluvieSpecError, VideoSpec, unknownSpecProps;
import 'package:fluvie/src/serialization/anchor_table.dart';
import 'package:fluvie/src/serialization/element_spec.dart';

Map<String, Object?> _label(String text) => {
  'type': 'Text',
  'text': text,
  'maxWidth': 240,
  'style': {'fontSize': 22, 'color': '#22201C'},
  'decoration': {'color': '#E6FFFEFC', 'cornerRadius': 999},
  'padding': {'horizontal': 16, 'vertical': 8},
};
void main() {
  testWidgets('caption pill hugs short text and wraps inside a safe width', (tester) async {
    final anchors = AnchorTable();
    Future<void> pump(String text) => tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: ElementSpec.fromJson(_label(text), anchors).build(anchors),
        ),
      ),
    );
    await pump('Together');
    final short = tester.getSize(find.byType(DecoratedBox));
    expect(short.width, lessThan(240));
    await pump('A very long caption that wraps without escaping the frame');
    final long = tester.getSize(find.byType(DecoratedBox));
    expect(long.width, lessThanOrEqualTo(240));
    expect(long.height, greaterThan(short.height));
    expect(tester.takeException(), isNull);
  });
  test('frame fields round-trip without unknown-property warnings', () {
    final json = <String, Object?>{
      'fluvieSpec': 1,
      'size': 'hd',
      'scenes': [
        {
          'duration': '1s',
          'children': [_label('Together')],
        },
      ],
    };
    expect(unknownSpecProps(json), isEmpty);
    final spec = VideoSpec.fromJson(json);
    expect(VideoSpec.fromJson(spec.toJson()).toJson(), spec.toJson());
    expect(spec.build().totalFrames, 30);
  });
  test('invalid insets and widths fail before rendering', () {
    for (final value in [-1, double.nan, 'large']) {
      final json = _label('Hello')..['padding'] = {'horizontal': value};
      expect(
        () => ElementSpec.fromJson(json, AnchorTable()).build(AnchorTable()),
        throwsA(isA<FluvieSpecError>()),
      );
    }
    for (final value in [0, -2, double.infinity, 'wide']) {
      final json = _label('Hello')..['maxWidth'] = value;
      expect(
        () => ElementSpec.fromJson(json, AnchorTable()).build(AnchorTable()),
        throwsA(isA<FluvieSpecError>()),
      );
    }
  });
}
