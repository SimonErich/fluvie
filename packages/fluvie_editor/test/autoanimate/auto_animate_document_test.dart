import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

/// Two slides: an explicit `logo` pair, a content-identical headline, and
/// one unmatched element on each side.
Map<String, Object?> _deck({Map<String, Object?>? video, Map<String, Object?>? scene1Extra}) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  ...?video,
  'scenes': [
    {
      'duration': '60f',
      'layout': 'canvas',
      'children': [
        {
          'id': 'el-logo',
          'type': 'Box',
          'color': '#6C5CE7',
          'shared': 'logo',
          'transform': {'x': 0.5, 'y': 0.5, 'w': 0.4, 'h': 0.4},
        },
        {
          'id': 'el-title',
          'type': 'Text',
          'text': 'Fluvie',
          'style': {'fontSize': 32},
          'transform': {'x': 0.5, 'y': 0.85, 'w': 0.8, 'h': 0.15},
        },
        {
          'id': 'el-old',
          'type': 'Text',
          'text': 'Only on slide one',
          'transform': {'x': 0.5, 'y': 0.1, 'w': 0.8, 'h': 0.1},
        },
      ],
    },
    {
      'duration': '60f',
      'layout': 'canvas',
      ...?scene1Extra,
      'children': [
        {
          'id': 'el-logo-2',
          'type': 'Box',
          'color': '#6C5CE7',
          'shared': 'logo',
          'transform': {'x': 0.12, 'y': 0.12, 'w': 0.12, 'h': 0.12},
        },
        {
          'id': 'el-title-2',
          'type': 'Text',
          'text': 'Fluvie',
          'style': {'fontSize': 32},
          'transform': {'x': 0.3, 'y': 0.12, 'w': 0.5, 'h': 0.1},
        },
        {
          'id': 'el-new',
          'type': 'Box',
          'color': '#00B894',
          'transform': {'x': 0.7, 'y': 0.7, 'w': 0.2, 'h': 0.2},
        },
      ],
    },
  ],
};

String? _sharedOf(EditorDocument document, String id) =>
    document.elementJson(id)?['shared'] as String?;

void main() {
  group('applyAutoAnimate', () {
    test('writes one minted shared id onto both sides of every content pair', () {
      final document = EditorDocument.fromJson(_deck()).applyAutoAnimate(1);
      final minted = _sharedOf(document, 'el-title-2');
      expect(minted, isNotNull);
      expect(minted, startsWith('hero-'));
      expect(_sharedOf(document, 'el-title'), minted);
    });

    test('keeps the author explicit pair untouched and untracked', () {
      final document = EditorDocument.fromJson(_deck()).applyAutoAnimate(1);
      expect(_sharedOf(document, 'el-logo'), 'logo');
      expect(_sharedOf(document, 'el-logo-2'), 'logo');
      expect(document.sceneMeta(1)['autoShared'], isNot(contains('logo')));
    });

    test('leaves unmatched elements without shared ids', () {
      final document = EditorDocument.fromJson(_deck()).applyAutoAnimate(1);
      expect(_sharedOf(document, 'el-old'), isNull);
      expect(_sharedOf(document, 'el-new'), isNull);
    });

    test('tracks the applied state in the slide meta', () {
      final document = EditorDocument.fromJson(_deck()).applyAutoAnimate(1);
      final meta = document.sceneMeta(1);
      expect(meta['autoAnimate'], isTrue);
      expect(meta['autoShared'], [_sharedOf(document, 'el-title-2')]);
    });

    test('writes a crossFade enter when nothing governs the boundary', () {
      final document = EditorDocument.fromJson(_deck()).applyAutoAnimate(1);
      expect(document.sceneJson(1)['enter'], {'kind': 'crossFade', 'duration': '500ms'});
      expect(document.sceneMeta(1)['autoEnter'], isTrue);
    });

    test('leaves an authored boundary transition alone', () {
      final authored = {'kind': 'slide', 'duration': '400ms', 'from': 'right'};
      final document = EditorDocument.fromJson(
        _deck(scene1Extra: {'enter': authored}),
      ).applyAutoAnimate(1);
      expect(document.sceneJson(1)['enter'], authored);
      expect(document.sceneMeta(1)['autoEnter'], isNull);
    });

    test('a video default transition also counts as governed', () {
      final document = EditorDocument.fromJson(
        _deck(
          video: {
            'transition': {'kind': 'crossFade', 'duration': '12f'},
          },
        ),
      ).applyAutoAnimate(1);
      expect(document.sceneJson(1)['enter'], isNull);
    });

    test('re-running replaces stale pairings in one pass', () {
      var document = EditorDocument.fromJson(_deck()).applyAutoAnimate(1);
      final first = _sharedOf(document, 'el-title-2')!;
      // The previous headline changes: the old pair is stale.
      final title = document.elementJson('el-title')!..['text'] = 'Changed';
      document = document.replaceElement('el-title', title).applyAutoAnimate(1);
      expect(_sharedOf(document, 'el-title'), isNull);
      expect(_sharedOf(document, 'el-title-2'), isNull);
      expect(document.sceneMeta(1)['autoShared'], isNull);
      expect(first, startsWith('hero-'));
    });

    test('slide zero has no previous slide and pairs nothing', () {
      final document = EditorDocument.fromJson(_deck()).applyAutoAnimate(0);
      expect(document.autoAnimateOn(0), isTrue);
      expect(document.sceneMeta(0)['autoShared'], isNull);
      expect(document.sceneJson(0)['enter'], isNull);
    });

    test('minted ids skip shared ids the document already uses', () {
      final base = EditorDocument.fromJson(_deck());
      final logo = base.elementJson('el-logo')!..['shared'] = 'hero-1';
      final logo2 = base.elementJson('el-logo-2')!..['shared'] = 'hero-1';
      final document = base
          .replaceElement('el-logo', logo)
          .replaceElement('el-logo-2', logo2)
          .applyAutoAnimate(1);
      expect(_sharedOf(document, 'el-title-2'), 'hero-2');
    });
  });

  group('clearAutoAnimate', () {
    test('removes exactly what apply added', () {
      final before = EditorDocument.fromJson(_deck());
      final after = before.applyAutoAnimate(1).clearAutoAnimate(1);
      expect(after.toJson(), before.toJson());
    });

    test('keeps author-typed shared ids', () {
      final document = EditorDocument.fromJson(_deck()).applyAutoAnimate(1).clearAutoAnimate(1);
      expect(_sharedOf(document, 'el-logo'), 'logo');
      expect(_sharedOf(document, 'el-logo-2'), 'logo');
    });

    test('keeps an enter the author replaced after apply', () {
      final authored = {'kind': 'wipe', 'duration': '300ms', 'direction': 'right'};
      final document = EditorDocument.fromJson(
        _deck(),
      ).applyAutoAnimate(1).updateScene(1, {'enter': authored}).clearAutoAnimate(1);
      expect(document.sceneJson(1)['enter'], authored);
    });

    test('is a no-op without applied state', () {
      final before = EditorDocument.fromJson(_deck());
      expect(before.clearAutoAnimate(1).toJson(), before.toJson());
    });
  });

  group('reads', () {
    test('autoAnimateOn follows the meta', () {
      final off = EditorDocument.fromJson(_deck());
      expect(off.autoAnimateOn(1), isFalse);
      expect(off.applyAutoAnimate(1).autoAnimateOn(1), isTrue);
    });

    test('autoAnimatePairing pairs the adjacent slides', () {
      final pairing = EditorDocument.fromJson(_deck()).autoAnimatePairing(1);
      expect(pairing.pairs, hasLength(2));
      expect(pairing.unmatchedPrevious, ['el-old']);
      expect(pairing.unmatchedCurrent, ['el-new']);
    });

    test('autoAnimatePairing on slide zero has an empty previous side', () {
      final pairing = EditorDocument.fromJson(_deck()).autoAnimatePairing(0);
      expect(pairing.pairs, isEmpty);
      expect(pairing.unmatchedPrevious, isEmpty);
    });

    test('sharedPartnerOf finds the previous-slide carrier', () {
      final document = EditorDocument.fromJson(_deck()).applyAutoAnimate(1);
      expect(document.sharedPartnerOf(1, 'el-logo-2'), 'el-logo');
      expect(document.sharedPartnerOf(1, 'el-title-2'), 'el-title');
      expect(document.sharedPartnerOf(1, 'el-new'), isNull);
      expect(document.sharedPartnerOf(0, 'el-logo'), isNull);
    });

    test('linkCandidatesOf lists unpartnered previous-slide elements', () {
      final document = EditorDocument.fromJson(_deck()).applyAutoAnimate(1);
      expect(document.linkCandidatesOf(1), ['el-old']);
      expect(document.linkCandidatesOf(0), isEmpty);
    });

    test('linkedPairCountOf counts live pairs', () {
      final document = EditorDocument.fromJson(_deck());
      expect(document.linkedPairCountOf(1), 1); // the explicit logo pair
      expect(document.applyAutoAnimate(1).linkedPairCountOf(1), 2);
    });
  });

  group('linkShared', () {
    test('mints an author-level id onto both sides', () {
      final document = EditorDocument.fromJson(
        _deck(),
      ).linkShared(slide: 1, currentId: 'el-new', previousId: 'el-old');
      final minted = _sharedOf(document, 'el-new');
      expect(minted, 'hero-1');
      expect(_sharedOf(document, 'el-old'), minted);
      expect(document.sceneMeta(1)['autoShared'], isNull);
    });

    test("reuses the previous element's existing shared id", () {
      final document = EditorDocument.fromJson(
        _deck(),
      ).linkShared(slide: 1, currentId: 'el-new', previousId: 'el-logo');
      expect(_sharedOf(document, 'el-new'), 'logo');
      expect(_sharedOf(document, 'el-logo'), 'logo');
    });

    test('a manual link survives clearAutoAnimate', () {
      final document = EditorDocument.fromJson(_deck())
          .applyAutoAnimate(1)
          .linkShared(slide: 1, currentId: 'el-new', previousId: 'el-old')
          .clearAutoAnimate(1);
      expect(_sharedOf(document, 'el-new'), isNotNull);
      expect(_sharedOf(document, 'el-old'), _sharedOf(document, 'el-new'));
    });

    test('relinking an auto-paired element dissolves its old pair', () {
      final applied = EditorDocument.fromJson(_deck()).applyAutoAnimate(1);
      final document = applied.linkShared(slide: 1, currentId: 'el-title-2', previousId: 'el-old');
      expect(_sharedOf(document, 'el-title'), isNull);
      expect(_sharedOf(document, 'el-title-2'), _sharedOf(document, 'el-old'));
      expect(document.sceneMeta(1)['autoShared'], isNull);
    });
  });

  group('unlinkShared', () {
    test('an auto pair dissolves on both sides and untracks', () {
      final document = EditorDocument.fromJson(
        _deck(),
      ).applyAutoAnimate(1).unlinkShared(slide: 1, elementId: 'el-title-2');
      expect(_sharedOf(document, 'el-title-2'), isNull);
      expect(_sharedOf(document, 'el-title'), isNull);
      expect(document.sceneMeta(1)['autoShared'], isNull);
    });

    test('an author id leaves only the unlinked element', () {
      final document = EditorDocument.fromJson(
        _deck(),
      ).unlinkShared(slide: 1, elementId: 'el-logo-2');
      expect(_sharedOf(document, 'el-logo-2'), isNull);
      expect(_sharedOf(document, 'el-logo'), 'logo');
    });

    test('is a no-op for an unlinked element', () {
      final before = EditorDocument.fromJson(_deck());
      expect(before.unlinkShared(slide: 1, elementId: 'el-new').toJson(), before.toJson());
    });
  });
}
