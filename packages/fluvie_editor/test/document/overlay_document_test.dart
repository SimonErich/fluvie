// Overlays in the editor's document: found by id like anything else, owned by
// no slide, and drawn on the slide the editor block says — which is editorial,
// so it never moves the render digest.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

Map<String, Object?> _deck({List<Object?>? overlays, Map<String, Object?>? homes}) => {
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
        {'id': 'el-b', 'type': 'Text', 'text': 'two'},
      ],
    },
  ],
  if (homes != null) 'editor': {'editorSchema': 1, 'overlayHomes': homes},
};

List<Object?> _overlays() => [
  {'id': 'ov-logo', 'type': 'Text', 'text': 'logo'},
  {
    'id': 'ov-ticker',
    'type': 'Text',
    'text': 'live',
    'show': {'from': '10f', 'to': '80f'},
  },
];

EditorDocument _document({List<Object?>? overlays, Map<String, Object?>? homes}) =>
    EditorDocument.fromJson(_deck(overlays: overlays, homes: homes));

void main() {
  group('finding an overlay', () {
    test('reads it by id, exactly like a slide element', () {
      final document = _document(overlays: _overlays());

      expect(document.elementJson('ov-logo')!['text'], 'logo');
      expect(document.overlayIds, ['ov-logo', 'ov-ticker']);
      expect(document.isOverlay('ov-logo'), isTrue);
      expect(document.isOverlay('el-a'), isFalse);
    });

    test('reports no owning slide, because it has none', () {
      // Not the home: a verb that asks which slide holds this must not be
      // handed a slide it can insert into.
      final document = _document(overlays: _overlays(), homes: {'ov-logo': 1});

      expect(document.sceneOfElement('ov-logo'), isNull);
      expect(document.overlayHome('ov-logo'), 1);
    });

    test('shares the id namespace, so a minted id never collides with one', () {
      final document = _document(overlays: _overlays());

      expect(document.overlayIds, isNot(contains(document.nextId())));
    });
  });

  group('the home', () {
    test('is nothing until something sets it', () {
      expect(_document(overlays: _overlays()).overlayHome('ov-logo'), isNull);
    });

    test('is written into the editor block, so it never moves the digest', () {
      final document = _document(overlays: _overlays());

      final homed = document.withOverlayHome('ov-logo', 1);

      expect(homed.overlayHome('ov-logo'), 1);
      expect(homed.spec.digest(), document.spec.digest());
    });

    test('lists the overlays drawn on a slide', () {
      final document = _document(
        overlays: _overlays(),
        homes: {'ov-logo': 1, 'ov-ticker': 0},
      );

      expect(document.overlaysHomedOn(0), ['ov-ticker']);
      expect(document.overlaysHomedOn(1), ['ov-logo']);
    });

    test('clamps a home past the last slide rather than drawing nowhere', () {
      final document = _document(overlays: _overlays(), homes: {'ov-logo': 9});

      expect(document.overlayHome('ov-logo'), 1);
    });
  });

  group('the home through a structural slide change', () {
    test('follows its slide when one is inserted before it', () {
      final document = _document(
        overlays: _overlays(),
        homes: {'ov-logo': 1},
      ).addScene({'duration': '30f'}, at: 0);

      expect(document.overlayHome('ov-logo'), 2);
    });

    test('follows its slide when one before it is removed', () {
      final document = _document(overlays: _overlays(), homes: {'ov-logo': 1}).removeScene(0);

      expect(document.overlayHome('ov-logo'), 0);
    });

    test('re-homes rather than vanishing when its own slide is removed', () {
      // An overlay belongs to the video, not to the slide it happens to be
      // drawn on: deleting that slide must not delete the overlay's home.
      final document = _document(overlays: _overlays(), homes: {'ov-logo': 1}).removeScene(1);

      expect(document.overlayHome('ov-logo'), 0);
      expect(document.overlayIds, contains('ov-logo'));
    });

    test('follows a reorder', () {
      final document = _document(
        overlays: _overlays(),
        homes: {'ov-logo': 0},
      ).reorderScene(0, 1);

      expect(document.overlayHome('ov-logo'), 1);
    });
  });

  group('editing one', () {
    test('replaces it in place', () {
      final document = _document(overlays: _overlays());

      final edited = document.replaceElement('ov-logo', {
        'id': 'ov-logo',
        'type': 'Text',
        'text': 'new',
      });

      expect(edited.elementJson('ov-logo')!['text'], 'new');
      expect(edited.overlayIds, ['ov-logo', 'ov-ticker']);
    });

    test('removes it, and its home with it', () {
      final document = _document(overlays: _overlays(), homes: {'ov-logo': 1});

      final edited = document.removeOverlay('ov-logo');

      expect(edited.overlayIds, ['ov-ticker']);
      expect(edited.overlayHome('ov-logo'), isNull);
    });

    test('drops the whole key when the last overlay goes', () {
      final document = _document(overlays: [_overlays().first]);

      expect(document.removeOverlay('ov-logo').toJson().containsKey('overlays'), isFalse);
    });
  });
}
