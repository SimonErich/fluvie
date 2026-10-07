import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '90f',
      'layout': 'canvas',
      'children': [
        {
          'id': 'el-a',
          'type': 'Text',
          'text': 'title',
          'transform': {'x': 0.5, 'y': 0.3},
          'animate': [
            {'preset': 'fadeIn', 'duration': '30f'},
          ],
        },
      ],
    },
    {
      'duration': '60f',
      'children': [
        {'id': 'el-b', 'type': 'Box', 'color': '#6C5CE7'},
      ],
    },
  ],
};

Map<String, Object?> _themedDeck({String accent = '#FF6C5CE7'}) {
  final deck = _deck();
  deck['theme'] = {
    'palette': {'accent': accent},
  };
  final scenes = deck['scenes']! as List;
  final second = scenes[1]! as Map<String, Object?>;
  second['children'] = <Object?>[
    {
      'id': 'el-b',
      'type': 'Box',
      'color': {'token': 'accent'},
    },
  ];
  return deck;
}

Map<String, Object?> _masteredDeck({String chrome = '#FF6C5CE7'}) {
  final deck = _deck();
  deck['masters'] = {
    'content': {
      'children': [
        {'type': 'Box', 'color': chrome},
        {
          'type': 'Placeholder',
          'slot': 'title',
          'transform': {'x': 0.5, 'y': 0.3},
        },
      ],
    },
  };
  final scenes = deck['scenes']! as List;
  deck['scenes'] = <Object?>[
    scenes[0],
    {
      'duration': '60f',
      'master': 'content',
      'fills': {
        'title': {'id': 'el-b', 'type': 'Text', 'text': 'adopted'},
      },
    },
  ];
  return deck;
}

void main() {
  test('an adopting slide derives with its master applied', () {
    final doc = EditorDocument.fromJson(_masteredDeck());
    final derived = SlideDeriver().derive(doc, 1);
    expect(derived.video.scenes, hasLength(1));
    expect(derived.video.scenes.single.children, hasLength(2), reason: 'chrome plus the fill');
    expect(derived.totalFrames, 60);
  });

  test('a master edit re-derives the slide', () {
    final deriver = SlideDeriver();
    final purple = deriver.derive(EditorDocument.fromJson(_masteredDeck()), 1);
    final retinted = deriver.derive(
      EditorDocument.fromJson(_masteredDeck(chrome: '#FF00B894')),
      1,
    );
    expect(identical(retinted, purple), isFalse, reason: 'masters are part of the cache key');
    expect(identical(deriver.derive(EditorDocument.fromJson(_masteredDeck()), 1), purple), isTrue);
  });

  test('a themed slide derives: tokens resolve through the deck theme', () {
    final doc = EditorDocument.fromJson(_themedDeck());
    final derived = SlideDeriver().derive(doc, 1);
    expect(derived.video.scenes, hasLength(1));
    expect(derived.totalFrames, 60);
  });

  test('a theme change re-derives the slide', () {
    final deriver = SlideDeriver();
    final purple = deriver.derive(EditorDocument.fromJson(_themedDeck()), 1);
    final retinted = deriver.derive(
      EditorDocument.fromJson(_themedDeck(accent: '#FF00B894')),
      1,
    );
    expect(identical(retinted, purple), isFalse, reason: 'the theme is part of the cache key');
    expect(identical(deriver.derive(EditorDocument.fromJson(_themedDeck()), 1), purple), isTrue);
  });

  test('derives a single-scene video sized like the deck', () {
    final doc = EditorDocument.fromJson(_deck());
    final derived = SlideDeriver().derive(doc, 0);
    expect(derived.video.scenes, hasLength(1));
    expect(derived.video.fps, 30);
  });

  test('the settle frame clears the longest entrance', () {
    final doc = EditorDocument.fromJson(_deck());
    expect(SlideDeriver().derive(doc, 0).settleFrame, greaterThanOrEqualTo(30));
    expect(SlideDeriver().derive(doc, 1).settleFrame, greaterThanOrEqualTo(0));
  });

  test('carries the slide length for the transport', () {
    final doc = EditorDocument.fromJson(_deck());
    expect(SlideDeriver().derive(doc, 0).totalFrames, 90);
    expect(SlideDeriver().derive(doc, 1).totalFrames, 60);
  });

  test('memoizes per slide content, not per document instance', () {
    final deriver = SlideDeriver();
    final doc = EditorDocument.fromJson(_deck());
    final first = deriver.derive(doc, 0);
    expect(identical(deriver.derive(doc, 0), first), isTrue);

    // Editing the OTHER slide keeps this derivation cached.
    final otherEdited = doc.setTransform('el-b', {'x': 0.1, 'y': 0.1});
    expect(identical(deriver.derive(otherEdited, 0), first), isTrue);

    // Editing THIS slide re-derives.
    final thisEdited = doc.setTransform('el-a', {'x': 0.9, 'y': 0.9});
    expect(identical(deriver.derive(thisEdited, 0), first), isFalse);
  });

  test('the cache is capped', () {
    final deriver = SlideDeriver(capacity: 1);
    final doc = EditorDocument.fromJson(_deck());
    final first = deriver.derive(doc, 0);
    deriver.derive(doc, 1);
    expect(identical(deriver.derive(doc, 0), first), isFalse);
  });
}
