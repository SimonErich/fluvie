import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

const _palette = TimelinePhasePalette(
  enter: Color(0xFF00FF00),
  during: Color(0xFFFFFF00),
  exit: Color(0xFFFF0000),
);
const _links = TimelineLinkPalette(ends: Color(0xFF0000FF), starts: Color(0xFF00FFFF));

Map<String, Object?> _element(String id, List<Map<String, Object?>> animate, {String? anchor}) => {
  'id': id,
  'type': 'Box',
  'width': 40,
  'height': 20,
  'anchor': ?anchor,
  'animate': animate,
};

Map<String, Object?> _deck(List<Map<String, Object?>> children) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {'duration': '120f', 'children': children},
  ],
};

SlideTimelineModel _model(Map<String, Object?> json) => SlideTimelineModel.build(
  document: EditorDocument.fromJson(json),
  slide: 0,
  palette: _palette,
  linkPalette: _links,
);

void main() {
  test('a whenEnds trigger links its bar to the anchor bar end', () {
    final model = _model(
      _deck([
        _element('el-a', [
          {'preset': 'fadeIn', 'duration': '20f'},
        ], anchor: 'hero'),
        _element('el-b', [
          {
            'preset': 'fadeIn',
            'duration': '10f',
            'at': {'kind': 'whenEnds', 'anchor': 'hero'},
          },
        ]),
      ]),
    );
    expect(model.links, hasLength(1));
    final link = model.links.single;
    expect(link.id, 'el-b:0');
    expect(link.fromBarId, 'el-b:0');
    expect(link.toBarId, 'el-a:0');
    expect(link.toEdge, TimelineLinkEdge.end);
    expect(link.color, _links.ends);
    expect(link.label, isNull);
    // The link joins back to the same binding the bar carries.
    expect(model.bindings[link.id]!.elementId, 'el-b');
  });

  test('a whenStarts trigger lands on the anchor bar start in its own color', () {
    final model = _model(
      _deck([
        _element('el-a', [
          {'preset': 'fadeIn', 'duration': '20f'},
        ], anchor: 'hero'),
        _element('el-b', [
          {
            'preset': 'fadeIn',
            'duration': '10f',
            'at': {'kind': 'whenStarts', 'anchor': 'hero'},
            'delay': '12f',
          },
        ]),
      ]),
    );
    final link = model.links.single;
    expect(link.toEdge, TimelineLinkEdge.start);
    expect(link.color, _links.starts);
    // The authored offset shows on the connector.
    expect(link.label, '+12f');
  });

  test('a previous trigger links to the same element preceding bar', () {
    final model = _model(
      _deck([
        _element('el-a', [
          {'preset': 'fadeIn', 'duration': '20f'},
          {'preset': 'pulse', 'duration': '10f', 'at': 'previous'},
        ]),
      ]),
    );
    final link = model.links.single;
    expect(link.fromBarId, 'el-a:1');
    expect(link.toBarId, 'el-a:0');
    expect(link.toEdge, TimelineLinkEdge.end);
    expect(link.color, _links.ends);
  });

  test('the anchor bar is the one closing the anchor timeline', () {
    // el-a has two animations; whenEnds chains off the union end — the bar
    // that ends last, not the first bar.
    final model = _model(
      _deck([
        _element('el-a', [
          {'preset': 'fadeIn', 'duration': '10f'},
          {'preset': 'pulse', 'duration': '30f'},
        ], anchor: 'hero'),
        _element('el-b', [
          {
            'preset': 'fadeIn',
            'duration': '10f',
            'at': {'kind': 'whenEnds', 'anchor': 'hero'},
          },
        ]),
      ]),
    );
    expect(model.links.single.toBarId, 'el-a:1');
  });

  test('keyword triggers and missing anchors draw no links', () {
    final model = _model(
      _deck([
        _element('el-a', [
          {'preset': 'fadeIn', 'duration': '20f'},
        ]),
        _element('el-b', [
          {'preset': 'fadeIn', 'duration': '10f', 'at': 'sceneStart'},
        ]),
        _element('el-c', [
          {
            'preset': 'fadeIn',
            'duration': '10f',
            'at': {'kind': 'at', 'time': '1s'},
          },
        ]),
      ]),
    );
    expect(model.links, isEmpty);
  });

  test('links survive a save and reload byte for byte', () {
    final json = _deck([
      _element('el-a', [
        {'preset': 'fadeIn', 'duration': '20f'},
      ], anchor: 'hero'),
      _element('el-b', [
        {
          'preset': 'fadeIn',
          'duration': '10f',
          'at': {'kind': 'whenEnds', 'anchor': 'hero'},
        },
      ]),
    ]);
    final before = _model(json);
    final reloaded = SlideTimelineModel.build(
      document: EditorDocument.fromJson(EditorDocument.fromJson(json).toJson()),
      slide: 0,
      palette: _palette,
      linkPalette: _links,
    );
    expect(reloaded.links, before.links);
  });
}
