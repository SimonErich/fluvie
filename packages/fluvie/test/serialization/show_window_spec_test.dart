import 'package:flutter/widgets.dart' hide Animation, Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show Box, unknownSpecProps;
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/animation/motion_target.dart';
import 'package:fluvie/src/composition/introspection/frame_span.dart';
import 'package:fluvie/src/composition/introspection/timeline_introspection.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/core/video_size.dart';
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
      'duration': '90f',
      'layout': 'canvas',
      'children': children,
    },
  ],
};

void main() {
  group('the show window key', () {
    test('parses both bounds and is a reserved key', () {
      final anchors = AnchorTable();
      final spec = ElementSpec.fromJson({
        'type': 'Box',
        'color': '#101018',
        'show': {'from': '30f', 'to': '60f'},
      }, anchors);
      expect(spec.showFrom, const Time.frames(30));
      expect(spec.showTo, const Time.frames(60));
      expect(spec.window!.start, const Time.frames(30));
      expect(spec.window!.end, const Time.frames(60));
      expect(ElementSpec.reservedElementKeys, contains('show'));
      expect(knownElementProps.values.any((props) => props.contains('show')), isFalse);
    });

    test('a missing bound falls to the scene edge (the defaults law)', () {
      final anchors = AnchorTable();
      final fromOnly = ElementSpec.fromJson({
        'type': 'Box',
        'color': '#101018',
        'show': {'from': '30f'},
      }, anchors);
      expect(fromOnly.showTo, isNull);
      expect(fromOnly.window!.start, const Time.frames(30));
      expect(fromOnly.window!.end, const Time.relative(1));
      final toOnly = ElementSpec.fromJson({
        'type': 'Box',
        'color': '#101018',
        'show': {'to': '60f'},
      }, anchors);
      expect(toOnly.showFrom, isNull);
      expect(toOnly.window!.start, Time.zero);
      expect(toOnly.window!.end, const Time.frames(60));
    });

    test('no show key means no window', () {
      final spec = ElementSpec.fromJson({'type': 'Box', 'color': '#101018'}, AnchorTable());
      expect(spec.showFrom, isNull);
      expect(spec.showTo, isNull);
      expect(spec.window, isNull);
    });

    test('an empty show object is a parse error', () {
      expect(
        () => ElementSpec.fromJson(
          {
            'type': 'Box',
            'color': '#101018',
            'show': <String, Object?>{},
          },
          AnchorTable(),
          path: const ['children', '0'],
        ),
        throwsA(
          isA<FluvieSpecError>().having((error) => error.path, 'path', [
            'children',
            '0',
            'show',
          ]),
        ),
      );
    });

    test('a non-object show is a parse error', () {
      expect(
        () => ElementSpec.fromJson({
          'type': 'Box',
          'color': '#101018',
          'show': '2s',
        }, AnchorTable()),
        throwsA(isA<FluvieSpecError>().having((error) => error.path, 'path', ['show'])),
      );
    });

    test('a malformed bound reports its path', () {
      expect(
        () => ElementSpec.fromJson({
          'type': 'Box',
          'color': '#101018',
          'show': {'from': 5},
        }, AnchorTable()),
        throwsA(
          isA<FluvieSpecError>().having((error) => error.path, 'path', ['show', 'from']),
        ),
      );
    });

    test('toJson re-emits only the authored bounds, after visible, before animate', () {
      final anchors = AnchorTable();
      final json = ElementSpec.fromJson({
        'type': 'Box',
        'color': '#101018',
        'visible': false,
        'show': {'from': '30f'},
        'animate': [
          {'preset': 'fadeIn'},
        ],
      }, anchors).toJson();
      expect(json['show'], {'from': '30f'});
      final keys = json.keys.toList();
      expect(keys.indexOf('show'), keys.indexOf('visible') + 1);
      expect(keys.indexOf('animate'), keys.indexOf('show') + 1);
      final twice = ElementSpec.fromJson(json, AnchorTable()).toJson();
      expect(twice, json);
      final toOnly = ElementSpec.fromJson({
        'type': 'Box',
        'color': '#101018',
        'show': {'to': '60f'},
      }, anchors).toJson();
      expect(toOnly['show'], {'to': '60f'});
    });

    test('show counts into the digest', () {
      final plain = VideoSpec.fromJson(
        _document([
          {'type': 'Box', 'color': '#101018'},
        ]),
      );
      final windowed = VideoSpec.fromJson(
        _document([
          {
            'type': 'Box',
            'color': '#101018',
            'show': {'from': '30f'},
          },
        ]),
      );
      expect(windowed.digest(), isNot(plain.digest()));
    });

    test('show is never unknown; a typo inside is a closed-shape warning', () {
      expect(
        unknownSpecProps(
          _document([
            {
              'type': 'Box',
              'color': '#101018',
              'show': {'from': '30f', 'to': '60f'},
            },
          ]),
        ),
        isEmpty,
      );
      final warnings = unknownSpecProps(
        _document([
          {
            'type': 'Box',
            'color': '#101018',
            'show': {'frm': '30f'},
          },
        ]),
      );
      expect(warnings, hasLength(1));
      expect(warnings.single.message, contains('frm'));
      expect(warnings.single.path, ['scenes', '0', 'children', '0', 'show']);
    });

    test('every element schema variant refs the closed show def', () {
      final defs = videoSpecSchema[r'$defs']! as Map<String, Object?>;
      final element = defs['element']! as Map<String, Object?>;
      final variants = (element['oneOf']! as List<Object?>).cast<Map<String, Object?>>();
      for (final variant in variants) {
        final properties = variant['properties']! as Map<String, Object?>;
        expect(
          properties['show'],
          {r'$ref': r'#/$defs/show'},
          reason: '${properties['type']} must advertise show',
        );
      }
      final show = defs['show']! as Map<String, Object?>;
      expect(show['additionalProperties'], isFalse);
      expect(show['minProperties'], 1);
      final bounds = show['properties']! as Map<String, Object?>;
      expect(bounds.keys.toSet(), {'from', 'to'});
      expect(bounds['from'], {r'$ref': r'#/$defs/time'});
      expect(bounds['to'], {r'$ref': r'#/$defs/time'});
    });
  });

  group('building a show window', () {
    test('a show-only element still animates: one MotionTarget, empty animations', () {
      final anchors = AnchorTable();
      final spec = ElementSpec.fromJson({
        'type': 'Box',
        'color': '#101018',
        'show': {'from': '30f', 'to': '60f'},
      }, anchors);
      final target = spec.build(anchors) as MotionTarget;
      expect(target.animations, isEmpty);
      expect(target.window!.start, const Time.frames(30));
      expect(target.window!.end, const Time.frames(60));
      expect(target.child, isA<Box>());
    });

    test('one call carries animations, anchor, and window together', () {
      final anchors = AnchorTable();
      final spec = ElementSpec.fromJson({
        'type': 'Box',
        'color': '#101018',
        'anchor': 'broll',
        'show': {'from': '30f'},
        'animate': [
          {'preset': 'fadeIn', 'duration': '12f'},
        ],
      }, anchors);
      final target = spec.build(anchors) as MotionTarget;
      expect(target.animations, hasLength(1));
      expect(target.anchor, same(anchors.resolve('broll')));
      expect(target.window!.start, const Time.frames(30));
      expect(target.window!.end, const Time.relative(1));
    });

    test('hidden wins: visible false plus show builds nothing mounted', () {
      final anchors = AnchorTable();
      final spec = ElementSpec.fromJson({
        'type': 'Box',
        'color': '#101018',
        'visible': false,
        'show': {'from': '30f', 'to': '60f'},
      }, anchors);
      final built = spec.build(anchors) as SizedBox;
      expect(built.width, 0);
      expect(built.height, 0);
      expect(built.child, isNull);
    });

    test('show on a Group windows the whole group', () {
      final anchors = AnchorTable();
      final spec = ElementSpec.fromJson({
        'type': 'Group',
        'show': {'from': '30f', 'to': '60f'},
        'children': [
          {'type': 'Box', 'color': '#6C5CE7'},
        ],
      }, anchors);
      final target = spec.build(anchors) as MotionTarget;
      expect(target.window!.start, const Time.frames(30));
      expect(target.child, isA<SizedBox>(), reason: 'the group box is the windowed child');
    });
  });

  group('a show window on the resolved timeline', () {
    test('the introspected window equals the authored range', () {
      final video = VideoSpec.fromJson(
        _document([
          {
            'id': 'el-broll',
            'type': 'Box',
            'color': '#101018',
            'show': {'from': '30f', 'to': '60f'},
          },
          {
            'id': 'el-late',
            'type': 'Box',
            'color': '#2ECC8F',
            'show': {'from': '30f'},
          },
          {
            'id': 'el-early',
            'type': 'Box',
            'color': '#E6483F',
            'show': {'to': '60f'},
          },
        ]),
      ).build();
      final scene = introspectTimeline(video).scenes.single;
      expect(scene.elementById('el-broll')!.window, const FrameSpan(30, 60));
      expect(scene.elementById('el-late')!.window, const FrameSpan(30, 90));
      expect(scene.elementById('el-early')!.window, const FrameSpan(0, 60));
    });

    test('animations resolve inside the window: the entrance plays at from', () {
      final video = VideoSpec.fromJson(
        _document([
          {
            'id': 'el-badge',
            'type': 'Box',
            'color': '#101018',
            'show': {'from': '30f', 'to': '60f'},
            'animate': [
              {'preset': 'fadeIn', 'duration': '12f'},
            ],
          },
        ]),
      ).build();
      final element = introspectTimeline(video).scenes.single.elementById('el-badge')!;
      expect(element.window, const FrameSpan(30, 60));
      expect(element.animations.single.span, const FrameSpan(30, 42));
    });

    test('a spec-built window resolves the same spans as its widget twin', () {
      final specVideo = VideoSpec.fromJson(
        _document([
          {
            'id': 'el-badge',
            'type': 'Box',
            'color': '#101018',
            'show': {'from': '30f', 'to': '60f'},
            'animate': [
              {'preset': 'fadeIn', 'duration': '12f'},
            ],
          },
          {
            'id': 'el-still',
            'type': 'Box',
            'color': '#2ECC8F',
            'show': {'from': '45f'},
          },
        ]),
      ).build();
      final twin = Video(
        size: const VideoSize(480, 270),
        scenes: [
          Scene(
            duration: const Time.frames(90),
            children: [
              const Box(color: Color(0xFF101018)).animate(
                [Animation.fadeIn(duration: const Time.frames(12))],
                window: const Time.frames(30).to(const Time.frames(60)),
              ),
              const Box(color: Color(0xFF2ECC8F)).show(from: const Time.frames(45)),
            ],
          ),
        ],
      );
      final fromSpec = introspectTimeline(specVideo).scenes.single;
      final fromWidgets = introspectTimeline(twin).scenes.single;
      expect(fromSpec.elements, hasLength(fromWidgets.elements.length));
      for (var i = 0; i < fromSpec.elements.length; i++) {
        expect(fromSpec.elements[i].window, fromWidgets.elements[i].window);
        expect(
          [for (final animation in fromSpec.elements[i].animations) animation.span],
          [for (final animation in fromWidgets.elements[i].animations) animation.span],
        );
      }
    });

    test('a window-less animated child inherits the group window', () {
      final video = VideoSpec.fromJson(
        _document([
          {
            'id': 'el-g',
            'type': 'Group',
            'show': {'from': '30f', 'to': '60f'},
            'children': [
              {
                'id': 'el-c',
                'type': 'Box',
                'color': '#6C5CE7',
                'animate': [
                  {'preset': 'fadeIn', 'duration': '6f'},
                ],
              },
            ],
          },
        ]),
      ).build();
      final scene = introspectTimeline(video).scenes.single;
      expect(scene.elementById('el-g')!.window, const FrameSpan(30, 60));
      expect(scene.elementById('el-c')!.window, const FrameSpan(30, 60));
      expect(scene.elementById('el-c')!.animations.single.span, const FrameSpan(30, 36));
    });

    test('a nested show resolves and clamps inside its enclosing window', () {
      // Registration now mirrors WindowScope and clip planning: the child
      // starts ten frames into its parent and clamps to the parent end.
      final video = VideoSpec.fromJson(
        _document([
          {
            'id': 'el-g',
            'type': 'Group',
            'show': {'from': '30f', 'to': '60f'},
            'children': [
              {
                'id': 'el-c',
                'type': 'Box',
                'color': '#6C5CE7',
                'show': {'from': '10f', 'to': '40f'},
              },
            ],
          },
        ]),
      ).build();
      final scene = introspectTimeline(video).scenes.single;
      expect(scene.elementById('el-c')!.window, const FrameSpan(40, 60));
    });
  });
}
