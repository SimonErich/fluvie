// One command made of several. A verb that has to touch more than one
// element still has to be one undo step, or undoing a ripple would walk the
// author back through its parts one at a time.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '120f',
      'children': [
        {
          'id': 'a',
          'type': 'Text',
          'text': 'one',
          'show': {'from': '0f', 'to': '30f'},
        },
        {
          'id': 'b',
          'type': 'Text',
          'text': 'two',
          'show': {'from': '30f', 'to': '60f'},
        },
      ],
    },
  ],
};

EditorDocument _document() => EditorDocument.fromJson(_deck());

const _shiftA = SetShowWindowCommand(id: 'a', fromFrames: 10, toFrames: 40);
const _shiftB = SetShowWindowCommand(id: 'b', fromFrames: 40, toFrames: 70);

void main() {
  test('applies its parts in order', () {
    final document = const SequenceCommand([
      _shiftA,
      _shiftB,
    ], label: 'Ripple').apply(_document());

    expect(document.elementJson('a')!['show'], {'from': '10f', 'to': '40f'});
    expect(document.elementJson('b')!['show'], {'from': '40f', 'to': '70f'});
  });

  test('a later part sees what an earlier one wrote', () {
    // The parts of a ripple are not independent: each one is computed against
    // the document, so applying them out of order or in parallel would be a
    // different edit.
    final document = const SequenceCommand([
      SetShowWindowCommand(id: 'a', fromFrames: 10, toFrames: 40),
      RemoveElementCommand(id: 'a'),
    ], label: 'Trim then drop').apply(_document());

    expect(document.elementJson('a'), isNull);
  });

  test('is one undo step whatever it holds', () {
    final history = DocumentHistory(_document())
      ..dispatch(const SequenceCommand([_shiftA, _shiftB], label: 'Ripple'))
      ..undo();

    expect(history.document.elementJson('a')!['show'], {'from': '0f', 'to': '30f'});
    expect(history.document.elementJson('b')!['show'], {'from': '30f', 'to': '60f'});
    expect(history.canUndo, isFalse);
  });

  test('names every element its parts touched, so undo re-selects them all', () {
    expect(
      const SequenceCommand([_shiftA, _shiftB], label: 'Ripple').affectedIds,
      {'a', 'b'},
    );
  });

  test('carries the label it was given, because only the caller knows the verb', () {
    expect(const SequenceCommand([_shiftA], label: 'Ripple delete').label, 'Ripple delete');
  });

  test('an empty sequence changes nothing rather than throwing', () {
    // A verb that found nothing to do returns null instead, but a sequence
    // that ends up empty must not be the thing that breaks.
    final document = _document();

    expect(const SequenceCommand([], label: 'Nothing').apply(document), same(document));
  });
}
