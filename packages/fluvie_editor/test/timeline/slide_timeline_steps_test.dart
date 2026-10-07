import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';

const _palette = TimelinePhasePalette(
  enter: Color(0xFF00FF00),
  during: Color(0xFFFFFF00),
  exit: Color(0xFFFF0000),
);
const _links = TimelineLinkPalette(ends: Color(0xFF0000FF), starts: Color(0xFF00FFFF));

Map<String, Object?> _element(String id, {int delay = 0, Map<String, Object?>? at}) => {
  'id': id,
  'type': 'Box',
  'width': 40,
  'height': 20,
  'animate': [
    {
      'preset': 'fadeIn',
      'duration': '20f',
      if (delay > 0) 'delay': '${delay}f',
      'at': ?at,
    },
  ],
};

Map<String, Object?> _deck({List<Object?>? steps, Map<String, Object?>? at}) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '120f',
      'children': [
        _element('el-1'),
        _element('el-2', delay: 30, at: at),
        _element('el-3', delay: 60),
      ],
      'steps': ?steps,
    },
  ],
};

List<Object?> get _twoSteps => [
  {
    'elements': ['el-2'],
  },
  {
    'elements': ['el-3'],
  },
];

SlideTimelineModel _model(Map<String, Object?> json) => SlideTimelineModel.build(
  document: EditorDocument.fromJson(json),
  slide: 0,
  palette: _palette,
  linkPalette: _links,
);

void main() {
  test('a step-less slide has no markers and no violation message', () {
    final model = _model(_deck());
    expect(model.markers, isEmpty);
    expect(model.validationMessage, isNull);
  });

  test('markers sit at each step settle frame with click-step labels', () {
    final model = _model(_deck(steps: _twoSteps));
    expect(model.markers, [
      const TimelineMarker(id: 'step:0', frame: 20, label: '2'),
      const TimelineMarker(id: 'step:1', frame: 50, label: '3'),
    ]);
    expect(model.stepLayout.memberIds, [
      ['el-1'],
      ['el-2'],
      ['el-3'],
    ]);
  });

  test('marker frames match compileSlidePlans exactly, marker for marker', () {
    final json = _deck(steps: _twoSteps);
    final model = _model(json);
    final spec = EditorDocument.fromJson(json).spec;
    final plan = compileSlidePlans(deckFromSpec(spec)).single;
    expect(model.markers, hasLength(plan.stepCount - 1));
    for (var k = 0; k < model.markers.length; k++) {
      expect(model.markers[k].frame, plan.steps[k].entranceFrames.toDouble());
    }
  });

  test('a cross-element trigger on a stepped element flags its bar', () {
    final json = _deck(
      steps: _twoSteps,
      at: {'kind': 'whenEnds', 'anchor': 'hero'},
    );
    // Declare the anchor the trigger points at.
    final children =
        ((json['scenes']! as List).first! as Map<String, Object?>)['children']! as List;
    (children.first! as Map<String, Object?>)['anchor'] = 'hero';
    final model = _model(json);
    TimelineBar bar(String id) =>
        model.tracks.expand((track) => track.bars).firstWhere((bar) => bar.id == id);
    expect(bar('el-2:0').violation, isTrue);
    expect(bar('el-1:0').violation, isFalse);
    expect(bar('el-3:0').violation, isFalse);
    expect(model.validationMessage, contains('inside a Stop'));
    // The mirror still lays markers out — the panel never goes dark.
    expect(model.markers, hasLength(2));
  });

  test('an un-stepped cross-element trigger is no violation', () {
    final json = _deck(at: {'kind': 'whenEnds', 'anchor': 'hero'});
    final children =
        ((json['scenes']! as List).first! as Map<String, Object?>)['children']! as List;
    (children.first! as Map<String, Object?>)['anchor'] = 'hero';
    final model = _model(json);
    expect(model.tracks.expand((track) => track.bars).any((bar) => bar.violation), isFalse);
    expect(model.validationMessage, isNull);
  });

  test('a stepped group flags the violating child bar too', () {
    final json = {
      'fluvieSpec': 1,
      'size': {'width': 320, 'height': 180},
      'fps': 30,
      'scenes': [
        {
          'duration': '120f',
          'children': [
            _element('el-1'),
            {
              'id': 'g1',
              'type': 'Group',
              'children': [
                _element('el-2', at: {'kind': 'whenEnds', 'anchor': 'hero'}),
              ],
            },
          ],
          'steps': [
            {
              'elements': ['g1'],
            },
          ],
        },
      ],
    };
    final children =
        ((json['scenes']! as List).first! as Map<String, Object?>)['children']! as List;
    (children.first! as Map<String, Object?>)['anchor'] = 'hero';
    final model = _model(json);
    final bar = model.tracks.expand((track) => track.bars).firstWhere((bar) => bar.id == 'el-2:0');
    expect(bar.violation, isTrue);
    expect(model.validationMessage, isNotNull);
  });

  test('broken step references surface as the validation message', () {
    final model = _model(
      _deck(
        steps: [
          {
            'elements': ['nobody'],
          },
        ],
      ),
    );
    expect(model.validationMessage, contains('nobody'));
  });
}
