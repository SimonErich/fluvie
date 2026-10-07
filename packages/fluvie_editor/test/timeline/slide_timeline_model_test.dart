import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show Ease, introspectTimeline;
import 'package:fluvie_editor/fluvie_editor.dart';

const _palette = TimelinePhasePalette(
  enter: Color(0xFF46A758),
  during: Color(0xFFFFB224),
  exit: Color(0xFFE5484D),
);

/// Two scenes so slide 1 starts at absolute frame 60 — every bar position
/// must come out slide-relative.
Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'children': [
        {'id': 'el-first', 'type': 'Text', 'text': 'one'},
      ],
    },
    {
      'duration': '120f',
      'children': [
        {
          'id': 'el-rel',
          'type': 'Text',
          'text': 'rel',
          'animate': [
            {'preset': 'fadeIn', 'duration': '15f', 'delay': '0.25r'},
          ],
        },
        {'id': 'el-bg', 'type': 'Box', 'width': 80, 'height': 40},
        {
          'id': 'el-title',
          'type': 'Text',
          'text': 'Title',
          'animate': [
            {'preset': 'fadeIn', 'duration': '30f', 'ease': 'bounce'},
            {'preset': 'float', 'amplitude': 4},
            {'preset': 'fadeOut', 'duration': '20f', 'delay': '0.5s'},
          ],
        },
        {
          'id': 'el-grp',
          'type': 'Group',
          'children': [
            {
              'id': 'el-a',
              'type': 'Text',
              'text': 'a',
              'animate': [
                {'preset': 'fadeIn', 'duration': '15f', 'delay': '10f'},
              ],
            },
            {'id': 'el-b', 'type': 'Text', 'text': 'b'},
          ],
        },
      ],
    },
  ],
  'editor': {
    'editorSchema': 1,
    'elements': {
      'el-bg': {'name': 'Background'},
    },
  },
};

SlideTimelineModel _model(EditorDocument document, {int slide = 1}) => SlideTimelineModel.build(
  document: document,
  slide: slide,
  palette: _palette,
  linkPalette: const TimelineLinkPalette(ends: Color(0xFF0000FF), starts: Color(0xFF00FFFF)),
);

void main() {
  test('tracks follow layers order, topmost first, group children indented', () {
    final model = _model(EditorDocument.fromJson(_deck()));
    // The layers panel shows topmost first, children included: el-b is
    // declared after el-a, so it covers it and lists first.
    expect(model.tracks.map((t) => t.id), [
      'el-grp',
      'el-b',
      'el-a',
      'el-title',
      'el-bg',
      'el-rel',
    ]);
    expect(model.tracks.map((t) => t.depth), [0, 1, 1, 0, 0, 0]);
    expect(model.tracks.first.isGroup, isTrue);
    expect(model.tracks.map((t) => t.label), [
      'Group',
      'Text',
      'Text',
      'Text',
      'Background',
      'Text',
    ]);
  });

  test('bars sit exactly on the introspected spans, made slide-relative', () {
    final document = EditorDocument.fromJson(_deck());
    final model = _model(document);
    final scene = introspectTimeline(document.spec.build()).scenes[1];
    final base = scene.span.start;
    expect(base, 60);
    final introspected = scene.elementById('el-title')!;
    final track = model.tracks.firstWhere((t) => t.id == 'el-title');
    expect(track.bars, hasLength(3));
    for (var i = 0; i < 3; i++) {
      expect(track.bars[i].start, (introspected.animations[i].span.start - base).toDouble());
      expect(track.bars[i].end, (introspected.animations[i].span.end - base).toDouble());
    }
    // The entrance starts when the slide starts — 0, not 60.
    expect(track.bars.first.start, 0);
    expect(model.totalFrames, scene.span.durationFrames);
    expect(model.fps, 30);
  });

  test('bars are colored by phase and badged by preset', () {
    final model = _model(EditorDocument.fromJson(_deck()));
    final bars = model.tracks.firstWhere((t) => t.id == 'el-title').bars;
    expect(bars[0].color, _palette.enter);
    expect(bars[1].color, _palette.during);
    expect(bars[2].color, _palette.exit);
    expect(bars.map((b) => b.badge), ['fadeIn', 'float', 'fadeOut']);
  });

  test('the easing sketch takes the authored curve, smooth otherwise', () {
    final model = _model(EditorDocument.fromJson(_deck()));
    final bars = model.tracks.firstWhere((t) => t.id == 'el-title').bars;
    expect(identical(bars[0].easing, Ease.bounce), isTrue);
    expect(identical(bars[1].easing, Ease.smooth), isTrue);
  });

  test('bindings join bars back to their document animation', () {
    final model = _model(EditorDocument.fromJson(_deck()));
    final title = model.tracks.firstWhere((t) => t.id == 'el-title');
    final binding = model.bindings[title.bars.first.id]!;
    expect(binding.elementId, 'el-title');
    expect(binding.index, 0);
    expect(binding.delayFrames, 0);
    expect(binding.durationFrames, 30);
    // A seconds delay resolves to frames (0.5s at 30fps).
    expect(model.bindings[title.bars[2].id]!.delayFrames, 15);
    // A frames delay stays frames.
    final grouped = model.tracks.firstWhere((t) => t.id == 'el-a');
    expect(model.bindings[grouped.bars.single.id]!.delayFrames, 10);
    // A relative delay resolves against the element's own window (120f).
    final relative = model.tracks.firstWhere((t) => t.id == 'el-rel');
    expect(model.bindings[relative.bars.single.id]!.delayFrames, 30);
  });

  test('palettes are values', () {
    const same = TimelinePhasePalette(
      enter: Color(0xFF46A758),
      during: Color(0xFFFFB224),
      exit: Color(0xFFE5484D),
    );
    expect(_palette, same);
    expect(_palette.hashCode, same.hashCode);
    expect(
      _palette,
      isNot(
        const TimelinePhasePalette(
          enter: Color(0xFF000000),
          during: Color(0xFFFFB224),
          exit: Color(0xFFE5484D),
        ),
      ),
    );
  });

  test('still elements keep their rows, honestly bar-less', () {
    final model = _model(EditorDocument.fromJson(_deck()));
    expect(model.tracks.firstWhere((t) => t.id == 'el-bg').bars, isEmpty);
    expect(model.tracks.firstWhere((t) => t.id == 'el-b').bars, isEmpty);
    expect(model.hasBars, isTrue);
  });

  test('a slide without animations reports no bars', () {
    final model = _model(EditorDocument.fromJson(_deck()), slide: 0);
    expect(model.tracks.map((t) => t.id), ['el-first']);
    expect(model.hasBars, isFalse);
  });
}
