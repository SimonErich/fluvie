import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/animation/effects/multi_keyframe_effect.dart';
import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/core/keyframe.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/serialization/anchor_table.dart';
import 'package:fluvie/src/serialization/animation_builder.dart';
import 'package:fluvie/src/serialization/animation_spec.dart';
import 'package:fluvie/src/serialization/spec_validation.dart';
import 'package:fluvie/src/serialization/video_spec_schema.dart';

/// Parses one animation node, checks the round-trip, and builds it.
Animation _build(Map<String, Object?> json) {
  final anchors = AnchorTable();
  final spec = AnimationSpec.fromJson(json, anchors);
  expect(spec.toJson(), json, reason: 'the codec round-trip is identity');
  return buildAnimation(spec, anchors);
}

void main() {
  group('the keyframes form parses', () {
    test('a keyframes list selects the keyframes kind', () {
      final spec = AnimationSpec.fromJson({
        'keyframes': [
          {'opacity': 0},
          {'opacity': 1},
        ],
      }, AnchorTable());
      expect(spec.kind, 'keyframes');
      expect(spec.isRaw, isFalse);
    });

    test('toJson never writes a preset key for the keyframes form', () {
      final spec = AnimationSpec.fromJson({
        'keyframes': [
          {'opacity': 0},
          {'opacity': 1},
        ],
      }, AnchorTable());
      expect(spec.toJson().containsKey('preset'), isFalse);
    });

    test('the full form round-trips identically', () {
      final json = <String, Object?>{
        'keyframes': [
          {'opacity': 0, 'y': 0.6},
          {'opacity': 1, 'y': -0.15},
          {'y': 0},
        ],
        'easings': ['out', 'smooth'],
        'positions': ['0f', '10f', '24f'],
        'phase': 'during',
        'duration': '24f',
        'delay': '5f',
        'at': 'sceneStart',
        'label': 'hop',
      };
      final spec = AnimationSpec.fromJson(json, AnchorTable());
      expect(spec.toJson(), json);
    });
  });

  group('the keyframes form builds', () {
    test('stops, easings, positions, phase, and the tail all arrive', () {
      final animation = _build({
        'keyframes': [
          {'opacity': 0, 'y': 0.6},
          {'opacity': 1, 'y': -0.15},
          {'y': 0},
        ],
        'easings': ['out', 'smooth'],
        'positions': ['0f', '10f', '24f'],
        'phase': 'during',
        'duration': '24f',
        'delay': '5f',
        'at': 'sceneStart',
        'label': 'hop',
      });
      final effect = animation.effect as MultiKeyframeEffect;
      expect(effect.stops, const [
        Keyframe(opacity: 0, y: 0.6),
        Keyframe(opacity: 1, y: -0.15),
        Keyframe(y: 0),
      ]);
      expect(effect.easings, [Ease.out, Ease.smooth]);
      expect(effect.at, const [Time.zero, Time.frames(10), Time.frames(24)]);
      expect(animation.phase, AnimationPhase.during);
      expect(animation.duration, const Time.frames(24));
      expect(animation.delay, const Time.frames(5));
      expect(animation.at, Trigger.sceneStart);
      expect(animation.label, 'hop');
    });

    test('the minimal two-stop form builds with every option defaulted', () {
      final animation = _build({
        'keyframes': [
          {'opacity': 0},
          {'opacity': 1},
        ],
      });
      final effect = animation.effect as MultiKeyframeEffect;
      expect(effect.stops, hasLength(2));
      expect(effect.easings, isNull);
      expect(effect.at, isNull);
      expect(animation.phase, AnimationPhase.enter);
      expect(animation.at, Trigger.auto);
    });

    test('builds the same effect the Dart constructor builds', () {
      final fromSpec = _build({
        'keyframes': [
          {'opacity': 0, 'y': 0.6},
          {'opacity': 1, 'y': -0.15},
          {'y': 0},
        ],
        'easings': ['out', 'smooth'],
        'positions': ['0f', '10f', '24f'],
      });
      final fromDart = Animation.keyframes(
        const [Keyframe(opacity: 0, y: 0.6), Keyframe(opacity: 1, y: -0.15), Keyframe(y: 0)],
        easings: const [Ease.out, Ease.smooth],
        at: const [Time.zero, Time.frames(10), Time.frames(24)],
      );
      final specEffect = fromSpec.effect as MultiKeyframeEffect;
      final dartEffect = fromDart.effect as MultiKeyframeEffect;
      expect(specEffect.stops, dartEffect.stops);
      expect(specEffect.easings, dartEffect.easings);
      expect(specEffect.at, dartEffect.at);
      const fractions = [0.0, 10 / 24, 1.0];
      for (var i = 0; i <= 20; i++) {
        final progress = i / 20;
        expect(
          specEffect.keyframeAt(progress, stopFractions: fractions),
          dartEffect.keyframeAt(progress, stopFractions: fractions),
          reason: 'the spec-built effect must match the Dart one at $progress',
        );
      }
    });
  });

  group('the keyframes form validates', () {
    void expectError(Map<String, Object?> json, String fragment) {
      expect(
        () => buildAnimation(AnimationSpec.fromJson(json, AnchorTable()), AnchorTable()),
        throwsA(
          isA<FluvieSpecError>().having(
            (error) => error.toString(),
            'message',
            contains(fragment),
          ),
        ),
      );
    }

    test('a non-list keyframes value fails', () {
      expectError({'keyframes': 'nope'}, 'list');
    });

    test('fewer than two keyframes fail', () {
      expectError({
        'keyframes': [
          {'opacity': 0},
        ],
      }, 'two');
    });

    test('a malformed stop fails with its index in the path', () {
      expectError({
        'keyframes': [
          {'opacity': 0},
          'nope',
        ],
      }, 'keyframes.1');
    });

    test('an easings list of the wrong length fails', () {
      expectError({
        'keyframes': [
          {'opacity': 0},
          {'opacity': 1},
        ],
        'easings': ['out', 'smooth'],
      }, 'one per segment');
    });

    test('an unknown easing name fails', () {
      expectError({
        'keyframes': [
          {'opacity': 0},
          {'opacity': 1},
        ],
        'easings': ['zigzag'],
      }, 'zigzag');
    });

    test('a positions list of the wrong length fails', () {
      expectError({
        'keyframes': [
          {'opacity': 0},
          {'opacity': 1},
        ],
        'positions': ['0f'],
      }, 'one per stop');
    });

    test('frame positions must strictly increase', () {
      expectError({
        'keyframes': [
          {'opacity': 0},
          {'opacity': 1},
        ],
        'positions': ['10f', '10f'],
      }, 'strictly increase');
    });

    test('second and millisecond positions compare in one clock', () {
      expectError({
        'keyframes': [
          {'opacity': 0},
          {'opacity': 1},
        ],
        'positions': ['0.5s', '400ms'],
      }, 'strictly increase');
    });

    test('uncapped relative positions must strictly increase', () {
      expectError({
        'keyframes': [
          {'opacity': 0},
          {'opacity': 1},
        ],
        'positions': ['0.8r', '0.2r'],
      }, 'strictly increase');
    });

    test('mixed-unit positions defer ordering to the resolver', () {
      // Frames and seconds only meet once the fps is known, so the parse
      // accepts them; the animation pipeline checks the resolved fractions.
      expect(
        _build({
          'keyframes': [
            {'opacity': 0},
            {'opacity': 1},
          ],
          'positions': ['20f', '0.1s'],
        }),
        isA<Animation>(),
      );
    });

    test('an unknown phase fails', () {
      expectError({
        'keyframes': [
          {'opacity': 0},
          {'opacity': 1},
        ],
        'phase': 'sideways',
      }, 'sideways');
    });
  });

  group('the unknown-property sweep knows the keyframes form', () {
    Map<String, Object?> doc(Map<String, Object?> animation) => {
      'fluvieSpec': 1,
      'scenes': [
        {
          'duration': '60f',
          'children': [
            {
              'type': 'Text',
              'text': 'hi',
              'animate': [animation],
            },
          ],
        },
      ],
    };

    test('a clean keyframes entry raises no warnings', () {
      final warnings = unknownSpecProps(
        doc({
          'keyframes': [
            {'opacity': 0},
            {'opacity': 1},
          ],
          'easings': ['out'],
          'positions': ['0f', '10f'],
          'phase': 'enter',
          'duration': '10f',
        }),
      );
      expect(warnings, isEmpty);
    });

    test('a stray key inside a keyframes entry is named', () {
      final warnings = unknownSpecProps(
        doc({
          'keyframes': [
            {'opacity': 0},
            {'opacity': 1},
          ],
          'bogus': 1,
        }),
      );
      expect(warnings, hasLength(1));
      expect(warnings.single.message, contains('bogus'));
    });
  });

  group('the schema advertises the keyframes form', () {
    Map<String, Object?> defs() => videoSpecSchema[r'$defs']! as Map<String, Object?>;

    test('a closed keyframe def mirrors the keyframe codec fields', () {
      final def = defs()['keyframe']! as Map<String, Object?>;
      expect(def['additionalProperties'], isFalse);
      final props = (def['properties']! as Map<String, Object?>).keys.toSet();
      expect(props, {
        'opacity',
        'x',
        'y',
        'scale',
        'scaleX',
        'scaleY',
        'rotation',
        'skewX',
        'skewY',
        'blur',
        'color',
        'origin',
      });
    });

    test('the animation def grows the keyframes form', () {
      final animation = defs()['animation']! as Map<String, Object?>;
      final props = animation['properties']! as Map<String, Object?>;
      final keyframes = props['keyframes']! as Map<String, Object?>;
      expect(keyframes['minItems'], 2);
      expect((keyframes['items']! as Map<String, Object?>)[r'$ref'], r'#/$defs/keyframe');
      expect(props.containsKey('easings'), isTrue);
      expect(props.containsKey('positions'), isTrue);
      expect(props.containsKey('phase'), isTrue);
    });
  });
}
