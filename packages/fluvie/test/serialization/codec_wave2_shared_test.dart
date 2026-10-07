import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show Box, Placed, SharedElement, unknownSpecProps;
import 'package:fluvie/src/animation/motion_target.dart';
import 'package:fluvie/src/composition/runtime/media_collector.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/serialization/anchor_table.dart';
import 'package:fluvie/src/serialization/element_spec.dart';
import 'package:fluvie/src/serialization/video_spec.dart';
import 'package:fluvie/src/serialization/video_spec_schema.dart';

Map<String, Object?> _twoScenes(Map<String, Object?> first, Map<String, Object?> second) => {
  'fluvieSpec': 1,
  'size': 'hd',
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'children': [first],
    },
    {
      'duration': '60f',
      'children': [second],
    },
  ],
};

void main() {
  group('shared element ids', () {
    test('shared parses, round-trips after anchor, and is reserved', () {
      final anchors = AnchorTable();
      final spec = ElementSpec.fromJson({
        'type': 'Box',
        'color': '#101018',
        'anchor': 'intro',
        'shared': 'logo',
      }, anchors);
      expect(spec.shared, 'logo');
      final json = spec.toJson();
      expect(json['shared'], 'logo');
      expect(
        json.keys.toList().indexOf('shared'),
        json.keys.toList().indexOf('anchor') + 1,
        reason: 'shared is emitted right after anchor',
      );
      expect(ElementSpec.reservedElementKeys, contains('shared'));
    });

    test('a shared element builds wrapped in a SharedElement', () {
      final anchors = AnchorTable();
      final spec = ElementSpec.fromJson({
        'type': 'Box',
        'color': '#101018',
        'shared': 'logo',
      }, anchors);
      final built = spec.build(anchors) as SharedElement;
      expect(built.anchor, same(anchors.resolve('logo')));
      expect(built.child, isA<Box>());
    });

    test('the shared wrap sits inside animate and transform', () {
      final anchors = AnchorTable();
      final spec = ElementSpec.fromJson({
        'type': 'Box',
        'color': '#101018',
        'shared': 'logo',
        'transform': {'x': 0.5, 'y': 0.5},
        'animate': [
          {'preset': 'fadeIn'},
        ],
      }, anchors);
      final placed = spec.build(anchors) as Placed;
      final animated = placed.child as MotionTarget;
      final shared = animated.child as SharedElement;
      expect(shared.child, isA<Box>());
    });

    test('two elements naming the same id resolve to the SAME anchor instance', () {
      final spec = VideoSpec.fromJson(
        _twoScenes(
          {'type': 'Box', 'color': '#6C5CE7', 'shared': 'logo'},
          {'type': 'Box', 'color': '#6C5CE7', 'shared': 'logo'},
        ),
      );
      final video = spec.build();
      final first = video.scenes[0].children.single as SharedElement;
      final second = video.scenes[1].children.single as SharedElement;
      expect(
        identical(first.anchor, second.anchor),
        isTrue,
        reason: 'anchor identity through the shared AnchorTable IS the hero pairing',
      );
    });

    test('media inside a shared element still reaches the collect pass', () {
      final spec = VideoSpec.fromJson(
        _twoScenes(
          {
            'type': 'Image',
            'source': {'kind': 'asset', 'value': 'fixtures/swatch.png'},
            'shared': 'hero',
          },
          {'type': 'Box', 'color': '#101018'},
        ),
      );
      expect(
        collectMediaSources(spec.build().scenes),
        {const MediaSource.asset('fixtures/swatch.png')},
        reason: 'the SharedElement wrapper must stay transparent to the structural walk',
      );
    });

    test('every element schema variant carries shared beside anchor', () {
      final defs = videoSpecSchema[r'$defs']! as Map<String, Object?>;
      final element = defs['element']! as Map<String, Object?>;
      final variants = element['oneOf']! as List<Object?>;
      for (final variant in variants.cast<Map<String, Object?>>()) {
        final properties = variant['properties']! as Map<String, Object?>;
        expect(properties, contains('anchor'));
        expect(
          properties['shared'],
          {'type': 'string'},
          reason: '${properties['type']} must advertise shared',
        );
      }
    });

    test('shared is never reported as an unknown property', () {
      expect(
        unknownSpecProps(
          _twoScenes(
            {'type': 'Text', 'text': 'hero', 'shared': 'headline'},
            {'type': 'Text', 'text': 'hero', 'shared': 'headline'},
          ),
        ),
        isEmpty,
      );
    });
  });
}
