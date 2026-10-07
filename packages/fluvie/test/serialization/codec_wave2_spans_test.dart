import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:flutter/rendering.dart' show Color, TextAlign, TextDecoration;
import 'package:flutter/widgets.dart' show FontWeight, Text, TextSpan;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show unknownSpecProps;
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/serialization/anchor_table.dart';
import 'package:fluvie/src/serialization/element_spec.dart';

/// Round-trips one element through the spec layer and returns the widget.
Object _build(Map<String, Object?> json) {
  final anchors = AnchorTable();
  final spec = ElementSpec.fromJson(json, anchors);
  expect(spec.toJson(), json, reason: 'the codec round-trip is identity');
  return spec.build(anchors);
}

Map<String, Object?> _doc(Map<String, Object?> element) => {
  'fluvieSpec': 1,
  'size': 'hd',
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'children': [element],
    },
  ],
};

void main() {
  group('Text spans', () {
    test('round-trips and builds a rich text', () {
      final widget =
          _build({
                'type': 'Text',
                'spans': [
                  {'text': 'Hello '},
                  {
                    'text': 'world',
                    'style': {'fontWeight': 'bold'},
                  },
                ],
                'style': {'fontSize': 32},
                'textAlign': 'center',
                'maxLines': 2,
              })
              as Text;
      expect(widget.data, isNull);
      expect(widget.style!.fontSize, 32);
      expect(widget.textAlign, TextAlign.center);
      expect(widget.maxLines, 2);
      final root = widget.textSpan! as TextSpan;
      final spans = root.children!.cast<TextSpan>();
      expect(spans, hasLength(2));
      expect(spans[0].text, 'Hello ');
      expect(spans[0].style, isNull);
      expect(spans[1].text, 'world');
      expect(spans[1].style!.fontWeight, FontWeight.bold);
    });

    test('a link span underlines, keeps its authored style, and carries the '
        'uri on its semantics', () {
      final widget =
          _build({
                'type': 'Text',
                'spans': [
                  {
                    'text': 'Fluvie',
                    'link': 'https://fluvie.dev',
                    'style': {'color': '#6C5CE7'},
                  },
                ],
              })
              as Text;
      final span = (widget.textSpan! as TextSpan).children!.single as TextSpan;
      expect(span.style!.decoration, TextDecoration.underline);
      expect(span.style!.color, const Color(0xFF6C5CE7));
      expect(span.semanticsLabel, 'Fluvie, link to https://fluvie.dev');
      expect(span.recognizer, isNot(isA<TapGestureRecognizer>()));
      expect(span.recognizer, isNull, reason: 'a render is never interactive');
    });

    test('a bare link span still underlines', () {
      final widget =
          _build({
                'type': 'Text',
                'spans': [
                  {'text': 'docs', 'link': 'https://fluvie.dev/docs'},
                ],
              })
              as Text;
      final span = (widget.textSpan! as TextSpan).children!.single as TextSpan;
      expect(span.style!.decoration, TextDecoration.underline);
    });

    test('text and spans are mutually exclusive, one is required', () {
      expect(
        () => _build({
          'type': 'Text',
          'text': 'plain',
          'spans': [
            {'text': 'rich'},
          ],
        }),
        throwsA(isA<FluvieSpecError>()),
      );
      expect(() => _build({'type': 'Text'}), throwsA(isA<FluvieSpecError>()));
    });

    test('an empty spans list errors', () {
      expect(
        () => _build({'type': 'Text', 'spans': <Object?>[]}),
        throwsA(isA<FluvieSpecError>()),
      );
    });

    test('a span without text errors with its path', () {
      expect(
        () => _build({
          'type': 'Text',
          'spans': [
            {'style': <String, Object?>{}},
          ],
        }),
        throwsA(
          isA<FluvieSpecError>().having((e) => e.path, 'path', containsAll(['spans', '0'])),
        ),
      );
    });

    test('a non-object span entry errors', () {
      expect(
        () => _build({
          'type': 'Text',
          'spans': ['loose'],
        }),
        throwsA(isA<FluvieSpecError>()),
      );
    });

    test('typos inside a span or its style report as unknown', () {
      expect(
        unknownSpecProps(
          _doc({
            'type': 'Text',
            'spans': [
              {'text': 'x', 'href': 'https://x.dev'},
            ],
          }),
        ),
        isNotEmpty,
      );
      expect(
        unknownSpecProps(
          _doc({
            'type': 'Text',
            'spans': [
              {
                'text': 'x',
                'style': {'colour': '#FF0000'},
              },
            ],
          }),
        ),
        isNotEmpty,
      );
    });

    test('a clean spans document reports none', () {
      expect(
        unknownSpecProps(
          _doc({
            'type': 'Text',
            'spans': [
              {'text': 'Hello '},
              {
                'text': 'Fluvie',
                'link': 'https://fluvie.dev',
                'style': {'color': '#6C5CE7'},
              },
            ],
          }),
        ),
        isEmpty,
      );
    });
  });
}
