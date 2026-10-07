import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

Map<String, Object?> _box(String id, String color, {String? shared, bool? visible}) => {
  'id': id,
  'type': 'Box',
  'color': color,
  'shared': ?shared,
  'visible': ?visible,
  'transform': {'x': 0.5, 'y': 0.5, 'w': 0.2, 'h': 0.2},
};

Map<String, Object?> _text(String id, String text, {double fontSize = 24}) => {
  'id': id,
  'type': 'Text',
  'text': text,
  'style': {'fontSize': fontSize},
  'transform': {'x': 0.5, 'y': 0.8, 'w': 0.6, 'h': 0.1},
};

void main() {
  group('pairElements', () {
    test('explicit shared ids matching on both sides pair first', () {
      final pairing = pairElements(
        previous: [_box('el-a', '#6C5CE7', shared: 'logo')],
        current: [_box('el-b', '#6C5CE7', shared: 'logo')],
      );
      expect(pairing.pairs, hasLength(1));
      final pair = pairing.pairs.single;
      expect(pair.previousId, 'el-a');
      expect(pair.currentId, 'el-b');
      expect(pair.sharedId, 'logo');
      expect(pair.source, SharedPairSource.explicitId);
      expect(pairing.unmatchedPrevious, isEmpty);
      expect(pairing.unmatchedCurrent, isEmpty);
    });

    test('an explicit key beats a content match', () {
      // el-plain is content-identical to el-b, but the author's shared id on
      // el-keyed claims the pairing.
      final pairing = pairElements(
        previous: [
          _box('el-plain', '#6C5CE7'),
          _box('el-keyed', '#6C5CE7', shared: 'logo'),
        ],
        current: [_box('el-b', '#6C5CE7', shared: 'logo')],
      );
      final explicit = pairing.pairs.single;
      expect(explicit.previousId, 'el-keyed');
      expect(explicit.currentId, 'el-b');
      expect(pairing.unmatchedPrevious, ['el-plain']);
    });

    test('content-identical elements pair despite transform and animate', () {
      final pairing = pairElements(
        previous: [
          {
            ..._text('el-t1', 'Fluvie'),
            'transform': const {'x': 0.5, 'y': 0.5, 'w': 0.8, 'h': 0.2},
          },
        ],
        current: [
          {
            ..._text('el-t2', 'Fluvie'),
            'animate': [
              {'preset': 'fadeIn', 'duration': '12f'},
            ],
          },
        ],
      );
      final pair = pairing.pairs.single;
      expect(pair.previousId, 'el-t1');
      expect(pair.currentId, 'el-t2');
      expect(pair.sharedId, isNull);
      expect(pair.source, SharedPairSource.content);
    });

    test('different content stays unmatched', () {
      final pairing = pairElements(
        previous: [_text('el-t1', 'One')],
        current: [_text('el-t2', 'Two')],
      );
      expect(pairing.pairs, isEmpty);
      expect(pairing.unmatchedPrevious, ['el-t1']);
      expect(pairing.unmatchedCurrent, ['el-t2']);
    });

    test('identical twins pair in document order', () {
      final pairing = pairElements(
        previous: [_box('el-p1', '#111111'), _box('el-p2', '#111111')],
        current: [_box('el-c1', '#111111'), _box('el-c2', '#111111')],
      );
      expect(pairing.pairs, hasLength(2));
      expect(pairing.pairs[0].previousId, 'el-p1');
      expect(pairing.pairs[0].currentId, 'el-c1');
      expect(pairing.pairs[1].previousId, 'el-p2');
      expect(pairing.pairs[1].currentId, 'el-c2');
    });

    test('an element with a dangling shared id never content-matches', () {
      // The author typed a shared id; the engine must not overrule it with a
      // content pairing even though a content-equal partner exists.
      final pairing = pairElements(
        previous: [_box('el-a', '#6C5CE7')],
        current: [_box('el-b', '#6C5CE7', shared: 'logo')],
      );
      expect(pairing.pairs, isEmpty);
      expect(pairing.unmatchedPrevious, ['el-a']);
      expect(pairing.unmatchedCurrent, ['el-b']);
    });

    test('a show window is timing, not content: windowed twins still pair', () {
      final pairing = pairElements(
        previous: [_box('el-a', '#6C5CE7')],
        current: [
          {
            ..._box('el-b', '#6C5CE7'),
            'show': {'from': '30f', 'to': '60f'},
          },
        ],
      );
      final pair = pairing.pairs.single;
      expect(pair.previousId, 'el-a');
      expect(pair.currentId, 'el-b');
      expect(pair.source, SharedPairSource.content);
    });

    test('invisible elements stay out of content matching', () {
      final pairing = pairElements(
        previous: [_box('el-a', '#6C5CE7', visible: false)],
        current: [_box('el-b', '#6C5CE7')],
      );
      expect(pairing.pairs, isEmpty);
      expect(pairing.unmatchedPrevious, ['el-a']);
      expect(pairing.unmatchedCurrent, ['el-b']);
    });

    test('groups never content-match but their children do', () {
      final pairing = pairElements(
        previous: [
          {
            'id': 'el-g1',
            'type': 'Group',
            'transform': const {'x': 0.5, 'y': 0.5, 'w': 0.8, 'h': 0.8},
            'children': [_box('el-inner-1', '#2ECC8F')],
          },
        ],
        current: [
          {
            'id': 'el-g2',
            'type': 'Group',
            'transform': const {'x': 0.5, 'y': 0.5, 'w': 0.8, 'h': 0.8},
            'children': [_box('el-inner-2', '#2ECC8F')],
          },
        ],
      );
      final pair = pairing.pairs.single;
      expect(pair.previousId, 'el-inner-1');
      expect(pair.currentId, 'el-inner-2');
      expect(pairing.unmatchedPrevious, ['el-g1']);
      expect(pairing.unmatchedCurrent, ['el-g2']);
    });

    test('groups still pair through explicit shared ids', () {
      final pairing = pairElements(
        previous: [
          {
            'id': 'el-g1',
            'type': 'Group',
            'shared': 'panel',
            'transform': const {'x': 0.5, 'y': 0.5, 'w': 0.8, 'h': 0.8},
            'children': const <Object?>[],
          },
        ],
        current: [
          {
            'id': 'el-g2',
            'type': 'Group',
            'shared': 'panel',
            'transform': const {'x': 0.2, 'y': 0.2, 'w': 0.3, 'h': 0.3},
            'children': const <Object?>[],
          },
        ],
      );
      expect(pairing.pairs.single.source, SharedPairSource.explicitId);
    });

    test('elements without ids are skipped entirely', () {
      final pairing = pairElements(
        previous: [
          {'type': 'Box', 'color': '#6C5CE7'},
        ],
        current: [
          {'type': 'Box', 'color': '#6C5CE7'},
        ],
      );
      expect(pairing.pairs, isEmpty);
      expect(pairing.unmatchedPrevious, isEmpty);
      expect(pairing.unmatchedCurrent, isEmpty);
    });

    test('a duplicate shared id within one side pairs first-wins', () {
      final pairing = pairElements(
        previous: [_box('el-a', '#111111', shared: 'logo')],
        current: [
          _box('el-b', '#222222', shared: 'logo'),
          _box('el-c', '#333333', shared: 'logo'),
        ],
      );
      expect(pairing.pairs.single.currentId, 'el-b');
      expect(pairing.unmatchedCurrent, ['el-c']);
    });

    test('empty inputs pair nothing', () {
      final pairing = pairElements(previous: const [], current: const []);
      expect(pairing.pairs, isEmpty);
      expect(pairing.unmatchedPrevious, isEmpty);
      expect(pairing.unmatchedCurrent, isEmpty);
    });
  });

  group('canonicalJson', () {
    test('is key-order independent', () {
      expect(
        canonicalJson({'b': 1, 'a': 2}),
        canonicalJson({'a': 2, 'b': 1}),
      );
    });

    test('distinguishes values and nesting', () {
      expect(canonicalJson({'a': 1}), isNot(canonicalJson({'a': 2})));
      expect(
        canonicalJson({
          'a': [1, 2],
        }),
        isNot(
          canonicalJson({
            'a': [2, 1],
          }),
        ),
      );
    });
  });
}
