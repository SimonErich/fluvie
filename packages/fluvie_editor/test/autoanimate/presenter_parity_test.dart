// Epic 8.2 acceptance: the presenter and the file render play the same
// morph — one machinery. Both builds run over the SAME VideoSpec, so the
// spec's one AnchorTable hands the pair the same Anchor instance in the
// plain render build and in the presenter's deckFromSpec build; anchor
// identity IS the hero pairing. Unmatched elements mount no SharedElement
// in either tree — they ride the slide's authored transition.
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'layout': 'canvas',
      'children': [
        {
          'id': 'el-hero',
          'type': 'Box',
          'color': '#6C5CE7',
          'transform': {'x': 0.5, 'y': 0.5, 'w': 0.4, 'h': 0.4},
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
      'children': [
        {
          'id': 'el-hero-2',
          'type': 'Box',
          'color': '#6C5CE7',
          'transform': {'x': 0.12, 'y': 0.12, 'w': 0.12, 'h': 0.12},
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

/// Every mounted SharedElement per scene of [video], via the structural
/// walk (hero slots implement CollectibleChildren, so nothing hides).
List<List<SharedElement>> _sharedElementsPerScene(Video video) => [
  for (final scene in video.scenes)
    [
      for (final child in scene.children)
        ...(() {
          final found = <SharedElement>[];
          walkWidgetTree(child, (widget) {
            if (widget is SharedElement) found.add(widget);
          });
          return found;
        })(),
    ],
];

void main() {
  test('the render build and the presenter build share the pair anchors', () {
    final document = const ApplyAutoAnimateCommand(
      slide: 1,
      enabled: true,
    ).apply(EditorDocument.fromJson(_deck()));
    final spec = document.spec;
    final render = _sharedElementsPerScene(spec.build());
    final presenter = _sharedElementsPerScene(deckFromSpec(spec));

    // Exactly the one content pair mounts hero slots — one per scene, in
    // both builds; the unmatched elements mount none.
    for (final build in [render, presenter]) {
      expect(build[0], hasLength(1));
      expect(build[1], hasLength(1));
    }
    final anchor = render[0].single.anchor!;
    expect(anchor.debugName, document.elementJson('el-hero-2')!['shared']);
    for (final slot in [render[1].single, presenter[0].single, presenter[1].single]) {
      expect(identical(slot.anchor, anchor), isTrue);
    }
  });

  test('the auto-animated deck still compiles into slide plans', () {
    final document = const ApplyAutoAnimateCommand(
      slide: 1,
      enabled: true,
    ).apply(EditorDocument.fromJson(_deck()));
    final plans = compileSlidePlans(deckFromSpec(document.spec));
    expect(plans, hasLength(2));
  });

  test('an untouched deck mounts no hero slots at all', () {
    final spec = EditorDocument.fromJson(_deck()).spec;
    for (final scene in _sharedElementsPerScene(spec.build())) {
      expect(scene, isEmpty);
    }
  });
}
