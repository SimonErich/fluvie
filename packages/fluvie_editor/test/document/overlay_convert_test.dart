// Converting between slide-local and global. The bar must not move a pixel
// either way: a slide-relative window and an absolute one are two ways of
// naming the same frames.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

/// Two slides of 60 and 90 frames, so slide 1 runs 60..150 absolute.
Map<String, Object?> _deck({Map<String, Object?>? show, List<Object?>? overlays}) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'overlays': ?overlays,
  'scenes': <Object?>[
    {
      'duration': '60f',
      'children': [
        {'id': 'el-a', 'type': 'Text', 'text': 'one'},
      ],
    },
    {
      'duration': '90f',
      'children': [
        {'id': 'el-b', 'type': 'Text', 'text': 'two', 'show': ?show},
      ],
    },
  ],
};

EditorDocument _document({Map<String, Object?>? show, List<Object?>? overlays}) =>
    EditorDocument.fromJson(_deck(show: show, overlays: overlays));

/// Slide 1's absolute span in this deck.
const _sceneStart = 60;
const _sceneFrames = 90;

EditorDocument _promote(EditorDocument document, {String id = 'el-b'}) =>
    MakeOverlayCommand(id: id, sceneStart: _sceneStart, sceneFrames: _sceneFrames).apply(document);

EditorDocument _demote(EditorDocument document, {String id = 'ov', int scene = 1}) =>
    MakeSceneLocalCommand(
      id: id,
      scene: scene,
      sceneStart: _sceneStart,
      sceneFrames: _sceneFrames,
    ).apply(document);

void main() {
  group('making an element global', () {
    test('rewrites its window to the frames it already occupied', () {
      // 10..40 on a slide starting at 60 is 70..100 on the video.
      final document = _promote(_document(show: {'from': '10f', 'to': '40f'}));

      expect(document.isOverlay('el-b'), isTrue);
      expect(document.elementJson('el-b')!['show'], {'from': '70f', 'to': '100f'});
    });

    test('gives a window-less element the frames its slide gave it', () {
      // No window means the whole slide, which as absolute frames is the
      // slide's own span — the bar does not move.
      final document = _promote(_document());

      expect(document.elementJson('el-b')!['show'], {'from': '60f', 'to': '150f'});
    });

    test('homes it on the slide it came from', () {
      expect(_promote(_document()).overlayHome('el-b'), 1);
    });

    test('takes it out of its slide', () {
      final document = _promote(_document());

      expect(document.elementIdsInScene(1), isEmpty);
      expect(document.sceneOfElement('el-b'), isNull);
    });

    test('leaves everything else about it alone', () {
      final document = _promote(_document(show: {'from': '10f', 'to': '40f'}));

      expect(document.elementJson('el-b')!['text'], 'two');
      expect(document.elementJson('el-b')!['type'], 'Text');
    });

    test('does nothing to an id no slide holds', () {
      final document = _document();

      expect(_promote(document, id: 'nobody').toJson(), document.toJson());
    });
  });

  group('making an overlay slide-local', () {
    List<Object?> overlay(Map<String, Object?> show) => [
      {'id': 'ov', 'type': 'Text', 'text': 'global', 'show': show},
    ];

    test('rewrites its window to the slide frames it already occupied', () {
      final document = _demote(
        _document(overlays: overlay({'from': '70f', 'to': '100f'})),
      );

      expect(document.isOverlay('ov'), isFalse);
      expect(document.elementJson('ov')!['show'], {'from': '10f', 'to': '40f'});
      expect(document.sceneOfElement('ov'), 1);
    });

    test('round-trips: out and back is where it started', () {
      // The whole point of the pair. Two names for the same frames.
      final start = _document(show: {'from': '10f', 'to': '40f'});

      final round = _demote(_promote(start), id: 'el-b');

      expect(round.elementJson('el-b')!['show'], {'from': '10f', 'to': '40f'});
      expect(round.sceneOfElement('el-b'), 1);
    });

    test('clamps a window that straddles the slide it lands in', () {
      // 30..200 crosses out of slide 1 (60..150). There is no honest way for a
      // slide-local element to outlive its slide, so it stops at the edge.
      final document = _demote(
        _document(overlays: overlay({'from': '30f', 'to': '200f'})),
      );

      expect(document.elementJson('ov')!['show'], {'from': '0f', 'to': '90f'});
    });

    test('drops the home with the overlay', () {
      final document = _demote(
        _document(overlays: overlay({'from': '70f', 'to': '100f'})).withOverlayHome('ov', 1),
      );

      expect(document.overlayHome('ov'), isNull);
      expect(document.overlayIds, isEmpty);
    });

    test('does nothing to an id that is not an overlay', () {
      final document = _document();

      expect(_demote(document, id: 'el-b').toJson(), document.toJson());
    });
  });

  group('either way', () {
    test('is one undo step', () {
      final history = DocumentHistory(_document(show: {'from': '10f', 'to': '40f'}))
        ..dispatch(
          const MakeOverlayCommand(id: 'el-b', sceneStart: _sceneStart, sceneFrames: _sceneFrames),
        );
      expect(history.document.isOverlay('el-b'), isTrue);

      history.undo();

      expect(history.document.isOverlay('el-b'), isFalse);
      expect(history.document.elementJson('el-b')!['show'], {'from': '10f', 'to': '40f'});
      expect(history.canUndo, isFalse);
    });
  });
}
