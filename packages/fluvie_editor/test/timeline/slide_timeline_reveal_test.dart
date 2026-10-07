import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show introspectTimeline;
import 'package:fluvie_editor/fluvie_editor.dart';

const _palette = TimelinePhasePalette(
  enter: Color(0xFF46A758),
  during: Color(0xFFFFB224),
  exit: Color(0xFFE5484D),
);

/// Two scenes so slide 1 starts at absolute frame 60 — every reveal bar must
/// come out slide-relative, exactly like the animation bars.
Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'children': [
        {'id': 'el-intro', 'type': 'Text', 'text': 'intro'},
      ],
    },
    {
      'duration': '120f',
      'children': [
        {'id': 'el-counter', 'type': 'Counter', 'to': 98, 'reveal': '2s'},
        {
          'id': 'el-code',
          'type': 'Code',
          'source': 'print(1);',
          'reveal': {'kind': 'typing', 'speed': '3f'},
        },
        {
          'id': 'el-code-lines',
          'type': 'Code',
          'source': 'a\nb',
          'reveal': {'kind': 'lineByLine', 'perLine': '5f'},
        },
        {
          'id': 'el-code-instant',
          'type': 'Code',
          'source': 'x',
          'reveal': {'kind': 'instant'},
        },
        {'id': 'el-plain', 'type': 'Text', 'text': 'plain'},
        {'id': 'el-zero', 'type': 'Counter', 'to': 1, 'reveal': '0f'},
        {'id': 'el-rel', 'type': 'Counter', 'to': 3, 'reveal': '0.5r'},
        {
          'id': 'el-both',
          'type': 'Counter',
          'to': 5,
          'reveal': '1s',
          'animate': [
            {'preset': 'fadeIn', 'duration': '15f'},
          ],
        },
      ],
    },
  ],
};

SlideTimelineModel _model(EditorDocument document) => SlideTimelineModel.build(
  document: document,
  slide: 1,
  palette: _palette,
  linkPalette: const TimelineLinkPalette(ends: Color(0xFF0000FF), starts: Color(0xFF00FFFF)),
);

void main() {
  test('a bare reveal element shows one display-only reveal bar', () {
    final model = _model(EditorDocument.fromJson(_deck()));
    final bars = model.tracks.firstWhere((t) => t.id == 'el-counter').bars;
    expect(bars, hasLength(1));
    final bar = bars.single;
    // "2s" at 30 fps is 60 frames, from the slide-relative scope start of 0.
    expect(bar.id, 'el-counter:reveal');
    expect(bar.start, 0);
    expect(bar.end, 60);
    expect(bar.badge, 'reveal');
    // A reveal is read-only: it registers no binding, so it cannot be retimed.
    expect(model.bindings.containsKey('el-counter:reveal'), isFalse);
    // The reveal bar keeps the timeline non-empty for a reveal-only slide.
    expect(model.hasBars, isTrue);
  });

  test('the reveal bar sits at the element scope, made slide-relative', () {
    final document = EditorDocument.fromJson(_deck());
    final model = _model(document);
    final base = introspectTimeline(document.spec.build()).scenes[1].span.start;
    expect(base, 60);
    // The bare Counter is alive the whole slide, so its reveal starts at 0.
    expect(model.tracks.firstWhere((t) => t.id == 'el-counter').bars.single.start, 0);
  });

  test('a code reveal union resolves through its carried time', () {
    final model = _model(EditorDocument.fromJson(_deck()));
    final typing = model.tracks.firstWhere((t) => t.id == 'el-code').bars.single;
    expect(typing.id, 'el-code:reveal');
    expect(typing.start, 0);
    expect(typing.end, 3);
    final lines = model.tracks.firstWhere((t) => t.id == 'el-code-lines').bars.single;
    expect(lines.end, 5);
  });

  test('an instant reveal draws no bar', () {
    final model = _model(EditorDocument.fromJson(_deck()));
    expect(model.tracks.firstWhere((t) => t.id == 'el-code-instant').bars, isEmpty);
  });

  test('a non-reveal element and a zero-length reveal stay bar-less', () {
    final model = _model(EditorDocument.fromJson(_deck()));
    expect(model.tracks.firstWhere((t) => t.id == 'el-plain').bars, isEmpty);
    expect(model.tracks.firstWhere((t) => t.id == 'el-zero').bars, isEmpty);
  });

  test('a relative reveal resolves against the slide window', () {
    final model = _model(EditorDocument.fromJson(_deck()));
    // 0.5 of the 120-frame slide is 60 frames.
    expect(model.tracks.firstWhere((t) => t.id == 'el-rel').bars.single.end, 60);
  });

  test('an element with both an animation and a reveal shows both bars', () {
    final model = _model(EditorDocument.fromJson(_deck()));
    final bars = model.tracks.firstWhere((t) => t.id == 'el-both').bars;
    expect(bars.map((b) => b.id), ['el-both:0', 'el-both:reveal']);
    // The animation bar keeps its binding; the reveal bar has none.
    expect(model.bindings.containsKey('el-both:0'), isTrue);
    expect(model.bindings.containsKey('el-both:reveal'), isFalse);
    // "1s" reveal is 30 frames from the element scope start.
    expect(bars.last.start, 0);
    expect(bars.last.end, 30);
  });
}
