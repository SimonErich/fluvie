import 'package:flutter/widgets.dart' hide Animation, Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart'
    show Box, Placed, SharedElement, SpecElementId, unknownSpecProps;
import 'package:fluvie/src/animation/motion_target.dart';
import 'package:fluvie/src/composition/runtime/media_collector.dart';
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';
import 'package:fluvie/src/serialization/anchor_table.dart';
import 'package:fluvie/src/serialization/element_spec.dart';
import 'package:fluvie/src/serialization/video_spec.dart';
import 'package:fluvie/src/serialization/video_spec_schema.dart';

Map<String, Object?> _document(List<Map<String, Object?>> children) => {
  'fluvieSpec': 1,
  'size': {'width': 480, 'height': 270},
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'layout': 'canvas',
      'children': children,
    },
  ],
};

const _canvasKey = Key('canvas');

Widget _mounted(Map<String, Object?> json, {int frame = 10}) => RenderModeContext(
  mode: RenderMode.capture,
  child: RenderControllerScope(
    controller: RenderController(initialFrame: frame),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          key: _canvasKey,
          width: 480,
          height: 270,
          child: VideoSpec.fromJson(json).build(),
        ),
      ),
    ),
  ),
);

/// Mounts one built element on a 480x270 canvas for layout assertions.
Widget _onCanvas(Widget element) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(
    child: SizedBox(key: _canvasKey, width: 480, height: 270, child: element),
  ),
);

void main() {
  group('the visible flag', () {
    test('parses, defaults to true, and is a reserved key', () {
      final anchors = AnchorTable();
      final hidden = ElementSpec.fromJson({
        'type': 'Box',
        'color': '#101018',
        'visible': false,
      }, anchors);
      expect(hidden.visible, isFalse);
      final defaulted = ElementSpec.fromJson({'type': 'Box', 'color': '#101018'}, anchors);
      expect(defaulted.visible, isTrue);
      expect(ElementSpec.reservedElementKeys, contains('visible'));
      expect(knownElementProps.values.any((props) => props.contains('visible')), isFalse);
    });

    test('toJson elides visible: true and emits visible: false after shared', () {
      final anchors = AnchorTable();
      final shown = ElementSpec.fromJson({
        'type': 'Box',
        'color': '#101018',
        'visible': true,
      }, anchors);
      expect(shown.toJson(), isNot(contains('visible')));
      final hidden = ElementSpec.fromJson({
        'type': 'Box',
        'color': '#101018',
        'anchor': 'intro',
        'shared': 'logo',
        'visible': false,
      }, anchors);
      final json = hidden.toJson();
      expect(json['visible'], isFalse);
      expect(
        json.keys.toList().indexOf('visible'),
        json.keys.toList().indexOf('shared') + 1,
        reason: 'visible is emitted right after shared',
      );
      final twice = ElementSpec.fromJson(json, AnchorTable()).toJson();
      expect(twice, json);
    });

    test('a hidden element builds nothing mounted', () {
      final anchors = AnchorTable();
      final spec = ElementSpec.fromJson({
        'type': 'Box',
        'color': '#E6483F',
        'visible': false,
        'shared': 'logo',
        'transform': {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 0.5},
        'animate': [
          {'preset': 'fadeIn'},
        ],
      }, anchors);
      final built = spec.build(anchors);
      expect(built, isA<SizedBox>());
      final sized = built as SizedBox;
      expect(sized.width, 0);
      expect(sized.height, 0);
      expect(sized.child, isNull);
    });

    testWidgets('a hidden element mounts a shrink and its sibling still renders', (tester) async {
      await tester.pumpWidget(
        _mounted(
          _document([
            {
              'type': 'Box',
              'color': '#E6483F',
              'visible': false,
              'transform': {'x': 0.25, 'y': 0.5, 'w': 0.4, 'h': 0.4},
            },
            {
              'type': 'Box',
              'color': '#2ECC8F',
              'transform': {'x': 0.75, 'y': 0.5, 'w': 0.4, 'h': 0.4},
            },
          ]),
        ),
      );
      expect(find.byType(Box), findsOneWidget, reason: 'only the visible Box mounts');
      final visibleRect = tester.getRect(find.byType(Box));
      final canvas = tester.getRect(find.byKey(_canvasKey));
      expect(visibleRect.center - canvas.topLeft, const Offset(360, 135));
      final shrunk = tester
          .widgetList<SizedBox>(find.byType(SizedBox))
          .where((sized) => sized.width == 0 && sized.height == 0);
      expect(shrunk, isNotEmpty, reason: 'the hidden slot keeps its place as a shrink');
    });

    test('visible counts into the digest', () {
      final shown = VideoSpec.fromJson(
        _document([
          {'type': 'Box', 'color': '#101018'},
        ]),
      );
      final hidden = VideoSpec.fromJson(
        _document([
          {'type': 'Box', 'color': '#101018', 'visible': false},
        ]),
      );
      expect(hidden.digest(), isNot(shown.digest()));
    });

    test('hidden media is never collected', () {
      final spec = VideoSpec.fromJson(
        _document([
          {
            'type': 'Image',
            'source': {'kind': 'asset', 'value': 'fixtures/swatch.png'},
            'visible': false,
          },
        ]),
      );
      expect(collectMediaSources(spec.build().scenes), isEmpty);
    });

    test('visible is never reported as an unknown property', () {
      expect(
        unknownSpecProps(
          _document([
            {'type': 'Text', 'text': 'hi', 'visible': false},
          ]),
        ),
        isEmpty,
      );
    });

    test('every element schema variant carries visible', () {
      final defs = videoSpecSchema[r'$defs']! as Map<String, Object?>;
      final element = defs['element']! as Map<String, Object?>;
      final variants = element['oneOf']! as List<Object?>;
      for (final variant in variants.cast<Map<String, Object?>>()) {
        final properties = variant['properties']! as Map<String, Object?>;
        expect(
          properties['visible'],
          {'type': 'boolean'},
          reason: '${properties['type']} must advertise visible',
        );
      }
    });
  });

  group('the Group element', () {
    test('is known, owns exactly a children prop, and round-trips verbatim', () {
      expect(knownElementTypes, contains('Group'));
      expect(knownElementProps['Group'], {'children'});
      final json = {
        'type': 'Group',
        'id': 'g1',
        'transform': {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 0.5},
        'children': [
          {'type': 'Box', 'color': '#6C5CE7'},
          {
            'type': 'Group',
            'children': [
              {'type': 'Box', 'color': '#2ECC8F', 'visible': false},
            ],
          },
        ],
        'animate': [
          {'preset': 'fadeIn'},
        ],
      };
      final once = ElementSpec.fromJson(json, AnchorTable()).toJson();
      expect(once['children'], json['children'], reason: 'children are stored verbatim');
      final twice = ElementSpec.fromJson(once, AnchorTable()).toJson();
      expect(twice, once);
    });

    test('builds the SizedBox.expand + Stack composition', () {
      final anchors = AnchorTable();
      final spec = ElementSpec.fromJson({
        'type': 'Group',
        'children': [
          {
            'type': 'Box',
            'color': '#6C5CE7',
            'transform': {'x': 0.3, 'y': 0.5, 'w': 0.4, 'h': 0.4},
          },
          {'type': 'Box', 'color': '#2ECC8F', 'shared': 'logo'},
        ],
      }, anchors);
      final built = spec.build(anchors);
      expect(built, isA<SizedBox>());
      final sized = built as SizedBox;
      expect(sized.width, double.infinity, reason: 'the group box fills its placement');
      expect(sized.height, double.infinity);
      final stack = sized.child! as Stack;
      expect(stack.children, hasLength(2));
      expect(stack.children.first, isA<Placed>());
      final shared = stack.children.last as SharedElement;
      expect(shared.anchor, same(anchors.resolve('logo')));
      expect(shared.child, isA<Box>());
    });

    test('an empty group renders nothing', () {
      final anchors = AnchorTable();
      final spec = ElementSpec.fromJson({'type': 'Group', 'children': <Object?>[]}, anchors);
      final stack = (spec.build(anchors) as SizedBox).child! as Stack;
      expect(stack.children, isEmpty);
    });

    test('a hidden child leaves a shrink in the stack; a hidden group hides everything', () {
      final anchors = AnchorTable();
      final spec = ElementSpec.fromJson({
        'type': 'Group',
        'children': [
          {'type': 'Box', 'color': '#E6483F', 'visible': false},
        ],
      }, anchors);
      final stack = (spec.build(anchors) as SizedBox).child! as Stack;
      final shrink = stack.children.single as SizedBox;
      expect(shrink.width, 0);
      expect(shrink.height, 0);

      final hiddenGroup = ElementSpec.fromJson({
        'type': 'Group',
        'visible': false,
        'children': [
          {'type': 'Box', 'color': '#E6483F'},
        ],
      }, anchors);
      final built = hiddenGroup.build(anchors) as SizedBox;
      expect(built.width, 0);
      expect(built.child, isNull);
    });

    test('a group with transform and animate wraps Placed around MotionTarget', () {
      final anchors = AnchorTable();
      final spec = ElementSpec.fromJson({
        'type': 'Group',
        'id': 'g1',
        'transform': {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 0.5},
        'children': [
          {'type': 'Box', 'color': '#6C5CE7'},
        ],
        'animate': [
          {'preset': 'fadeIn'},
        ],
      }, anchors);
      final placed = spec.build(anchors) as Placed;
      expect(placed.id, 'g1');
      final marker = placed.child as SpecElementId;
      expect(marker.id, 'g1');
      final target = marker.child as MotionTarget;
      expect(target.child, isA<SizedBox>());
    });

    testWidgets('child transforms resolve against the group box, not the canvas', (tester) async {
      final anchors = AnchorTable();
      final spec = ElementSpec.fromJson({
        'type': 'Group',
        'transform': {'x': 0.25, 'y': 0.25, 'w': 0.5, 'h': 0.5},
        'children': [
          {
            'type': 'Box',
            'color': '#6C5CE7',
            'transform': {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 0.5},
          },
        ],
      }, anchors);
      await tester.pumpWidget(_onCanvas(spec.build(anchors)));
      final canvas = tester.getRect(find.byKey(_canvasKey));
      final box = tester.getRect(find.byType(Box));
      // The centered group at (0.25, 0.25) x (0.5, 0.5) occupies the canvas
      // rect (0, 0)-(240, 135); the child's center fraction lands at the
      // center of THAT box: canvas (120, 67.5), a quarter of the child's
      // half-size fractions of the canvas.
      expect(box.size, const Size(120, 67.5));
      expect(box.center - canvas.topLeft, const Offset(120, 67.5));
    });

    testWidgets('groups nest: an inner group maps fractions of the outer box', (tester) async {
      final anchors = AnchorTable();
      final spec = ElementSpec.fromJson({
        'type': 'Group',
        'transform': {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 0.5},
        'children': [
          {
            'type': 'Group',
            'transform': {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 0.5},
            'children': [
              {
                'type': 'Box',
                'color': '#F0D86A',
                'transform': {'x': 1.0, 'y': 1.0, 'w': 0.5, 'h': 0.5},
              },
            ],
          },
        ],
      }, anchors);
      await tester.pumpWidget(_onCanvas(spec.build(anchors)));
      final canvas = tester.getRect(find.byKey(_canvasKey));
      final box = tester.getRect(find.byType(Box));
      // Outer box: (120, 67.5)-(360, 202.5). Inner box: (180, 101.25) sized
      // (120, 67.5). The child's (1.0, 1.0) center is the inner box's
      // bottom-right corner: canvas (300, 168.75).
      expect(box.size, const Size(60, 33.75));
      expect(box.center - canvas.topLeft, const Offset(300, 168.75));
    });

    test('media inside a group child still reaches the collect pass', () {
      final spec = VideoSpec.fromJson(
        _document([
          {
            'type': 'Group',
            'transform': {'x': 0.5, 'y': 0.5, 'w': 0.8, 'h': 0.8},
            'children': [
              {
                'type': 'Image',
                'source': {'kind': 'asset', 'value': 'fixtures/swatch.png'},
              },
            ],
          },
        ]),
      );
      expect(collectMediaSources(spec.build().scenes), {
        const MediaSource.asset('fixtures/swatch.png'),
      });
    });

    test('a group needs a children list and each entry must be an element object', () {
      final anchors = AnchorTable();
      expect(
        () => ElementSpec.fromJson({'type': 'Group'}, anchors).build(anchors),
        throwsA(
          isA<FluvieSpecError>().having((error) => error.path, 'path', ['children']),
        ),
      );
      expect(
        () => ElementSpec.fromJson({
          'type': 'Group',
          'children': [1],
        }, anchors).build(anchors),
        throwsA(
          isA<FluvieSpecError>().having((error) => error.path, 'path', ['children', '0']),
        ),
      );
    });

    test('validation recurses into group children at any depth', () {
      final warnings = unknownSpecProps(
        _document([
          {
            'type': 'Group',
            'children': [
              {
                'type': 'Group',
                'children': [
                  {'type': 'Box', 'colr': '#FFFFFF'},
                ],
              },
            ],
          },
        ]),
      );
      expect(warnings, hasLength(1));
      expect(warnings.single.message, contains('colr'));
      expect(warnings.single.path, [
        'scenes',
        '0',
        'children',
        '0',
        'children',
        '0',
        'children',
        '0',
      ]);
    });

    test('children stays a Group prop; on any other element it is unknown', () {
      final warnings = unknownSpecProps(
        _document([
          {
            'type': 'Box',
            'color': '#101018',
            'children': <Object?>[],
          },
        ]),
      );
      expect(warnings, hasLength(1));
      expect(warnings.single.message, contains('children'));
    });

    test('the schema closes the Group variant over type and children', () {
      final defs = videoSpecSchema[r'$defs']! as Map<String, Object?>;
      final element = defs['element']! as Map<String, Object?>;
      final variants = (element['oneOf']! as List<Object?>).cast<Map<String, Object?>>();
      final group = variants.singleWhere(
        (variant) =>
            ((variant['properties']! as Map<String, Object?>)['type']!
                as Map<String, Object?>)['const'] ==
            'Group',
      );
      expect(group['required'], ['type', 'children']);
      final properties = group['properties']! as Map<String, Object?>;
      expect(properties['children'], {
        'type': 'array',
        'description':
            "The grouped elements; each child's transform is a fraction of the group's box.",
        'items': {r'$ref': r'#/$defs/element'},
      });
    });
  });
}
