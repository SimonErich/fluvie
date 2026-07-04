import 'package:flutter/widgets.dart' show Text, Widget;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/composition/background/background.dart';
import 'package:fluvie/src/composition/box.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/elements/counter.dart';
import 'package:fluvie/src/elements/image.dart';
import 'package:fluvie/src/serialization/anchor_table.dart';
import 'package:fluvie/src/serialization/animation_builder.dart';
import 'package:fluvie/src/serialization/animation_spec.dart';
import 'package:fluvie/src/serialization/background_spec.dart';
import 'package:fluvie/src/serialization/element_spec.dart';
import 'package:fluvie/src/serialization/scene_spec.dart';

Animation _anim(Map<String, Object?> json) =>
    buildAnimation(AnimationSpec.fromJson(json, AnchorTable()));

Widget _elem(Map<String, Object?> json) {
  final table = AnchorTable();
  return ElementSpec.fromJson(json, table).build(table);
}

Background _bg(Map<String, Object?> json) => BackgroundSpec.fromJson(json).build();

void main() {
  group('buildAnimation', () {
    test('builds every preset', () {
      const presets = <Map<String, Object?>>[
        {'preset': 'fadeIn'},
        {'preset': 'fadeOut'},
        {'preset': 'slideIn', 'from': 'top'},
        {'preset': 'slideOut', 'to': 'bottom'},
        {'preset': 'slideFade', 'from': 'left'},
        {'preset': 'pop', 'overshoot': 1.2},
        {'preset': 'scaleIn', 'from': 0.8},
        {'preset': 'blurIn', 'sigma': 8},
        {'preset': 'blurOut', 'sigma': 8},
        {'preset': 'grain', 'amount': 0.3},
        {'preset': 'vignette', 'amount': 0.4},
        {'preset': 'spin', 'per': '3s'},
        {'preset': 'drift', 'to': 'left', 'distance': 0.2},
        {'preset': 'kenBurns', 'zoom': 1.3, 'pan': 'right'},
      ];
      for (final preset in presets) {
        expect(_anim(preset), isA<Animation>());
      }
    });

    test('builds raw from/to/fromTo animations', () {
      expect(
        _anim(const {
          'from': {'opacity': 0},
        }),
        isA<Animation>(),
      );
      expect(
        _anim(const {
          'to': {'opacity': 0},
        }),
        isA<Animation>(),
      );
      expect(
        _anim(const {
          'from': {'opacity': 0},
          'to': {'scale': 1},
        }),
        isA<Animation>(),
      );
    });

    test('carries the full timing tail and round-trips it', () {
      final spec = AnimationSpec.fromJson(const {
        'preset': 'fadeIn',
        'duration': '0.5s',
        'ease': 'snappy',
        'delay': '5f',
        'at': 'sceneStart',
        'stagger': {'each': '8f'},
        'repeat': {'forever': true},
        'label': 'hero',
      }, AnchorTable());
      expect(buildAnimation(spec).label, 'hero');
      expect(AnimationSpec.fromJson(spec.toJson(), AnchorTable()).toJson(), spec.toJson());
    });

    test('a raw animation omits the preset key and round-trips', () {
      final raw = AnimationSpec.fromJson(const {
        'from': {'opacity': 0},
        'duration': '10f',
        'spring': 'bouncy',
      }, AnchorTable());
      expect(raw.toJson().containsKey('preset'), isFalse);
      expect(AnimationSpec.fromJson(raw.toJson(), AnchorTable()).toJson(), raw.toJson());
    });

    test('rejects an animation with neither preset nor keyframe', () {
      expect(
        () => AnimationSpec.fromJson(const {}, AnchorTable()),
        throwsA(isA<FluvieSpecError>()),
      );
    });
  });

  group('buildElement', () {
    test('builds each element type', () {
      expect(_elem(const {'type': 'Text', 'text': 'hi'}), isA<Text>());
      expect(_elem(const {'type': 'Box', 'color': '#FF0000'}), isA<Box>());
      expect(
        _elem(const {
          'type': 'Box',
          'size': {'width': 0.5, 'height': 0.02},
        }),
        isA<Box>(),
      );
      expect(_elem(const {'type': 'Counter', 'to': 50}), isA<Counter>());
      expect(
        _elem(const {
          'type': 'Counter',
          'to': 100,
          'from': 10,
          'reveal': '2s',
          'style': {'fontSize': 40},
        }),
        isA<Counter>(),
      );
      expect(
        _elem(const {
          'type': 'Image',
          'source': {'kind': 'asset', 'value': 'a.png'},
          'fit': 'cover',
        }),
        isA<Image>(),
      );
      expect(
        _elem(const {
          'type': 'Image',
          'source': {'kind': 'network', 'value': 'https://example.com/a.png'},
        }),
        isA<Image>(),
      );
      expect(
        _elem(const {
          'type': 'Image',
          'source': {'kind': 'file', 'value': '/tmp/a.png'},
        }),
        isA<Image>(),
      );
    });

    test('wraps an element with animations or an anchor', () {
      final wrapped = _elem(const {
        'type': 'Text',
        'text': 'hi',
        'anchor': 'title',
        'animate': [
          {'preset': 'fadeIn'},
        ],
      });
      expect(wrapped, isA<Widget>());
      expect(wrapped, isNot(isA<Text>()));
    });

    test('rejects malformed elements', () {
      expect(() => _elem(const {'type': 'Text'}), throwsA(isA<FluvieSpecError>()));
      expect(
        () => _elem(const {
          'type': 'Box',
          'size': {'width': 1},
        }),
        throwsA(isA<FluvieSpecError>()),
      );
      expect(() => _elem(const {'type': 'Counter'}), throwsA(isA<FluvieSpecError>()));
      expect(() => _elem(const {'type': 'Image'}), throwsA(isA<FluvieSpecError>()));
      expect(
        () => _elem(const {
          'type': 'Image',
          'source': {'kind': 'asset'},
        }),
        throwsA(isA<FluvieSpecError>()),
      );
      expect(
        () => _elem(const {
          'type': 'Image',
          'source': {'kind': 'bogus', 'value': 'x'},
        }),
        throwsA(isA<FluvieSpecError>()),
      );
    });

    test('rejects a bad element envelope', () {
      expect(() => ElementSpec.fromJson(const {}, AnchorTable()), throwsA(isA<FluvieSpecError>()));
      expect(
        () => ElementSpec.fromJson(const {'type': 'Nope'}, AnchorTable()),
        throwsA(isA<FluvieSpecError>()),
      );
      expect(
        () => ElementSpec.fromJson(const {
          'type': 'Text',
          'text': 'x',
          'animate': 'no',
        }, AnchorTable()),
        throwsA(isA<FluvieSpecError>()),
      );
      expect(
        () => ElementSpec.fromJson(const {
          'type': 'Text',
          'text': 'x',
          'animate': ['no'],
        }, AnchorTable()),
        throwsA(isA<FluvieSpecError>()),
      );
    });
  });

  group('buildBackground', () {
    test('builds each variant', () {
      expect(_bg(const {'kind': 'color', 'color': '#112233'}), isA<Background>());
      expect(
        _bg(const {
          'kind': 'gradient',
          'colors': ['#000000', '#FFFFFF'],
          'begin': 'topLeft',
          'end': 'bottomRight',
        }),
        isA<Background>(),
      );
      expect(
        _bg(const {
          'kind': 'radial',
          'colors': ['#000000', '#FFFFFF'],
        }),
        isA<Background>(),
      );
      expect(_bg(const {'kind': 'image', 'source': 'a.png', 'fit': 'contain'}), isA<Background>());
      expect(_bg(const {'kind': 'video', 'source': 'v.mp4'}), isA<Background>());
      expect(_bg(const {'kind': 'noise', 'scale': 2}), isA<Background>());
      expect(_bg(const {'kind': 'vhs'}), isA<Background>());
    });

    test('rejects malformed backgrounds', () {
      expect(() => BackgroundSpec.fromJson(const {}), throwsA(isA<FluvieSpecError>()));
      expect(
        () => BackgroundSpec.fromJson(const {'kind': 'sky'}),
        throwsA(isA<FluvieSpecError>()),
      );
      expect(
        () => _bg(const {'kind': 'gradient', 'colors': 'no'}),
        throwsA(isA<FluvieSpecError>()),
      );
      expect(() => _bg(const {'kind': 'image'}), throwsA(isA<FluvieSpecError>()));
    });
  });

  group('SceneSpec', () {
    test('builds and round-trips a full scene', () {
      final scene = SceneSpec.fromJson(const {
        'duration': '2s',
        'background': {'kind': 'color', 'color': '#000000'},
        'enter': {'kind': 'cut'},
        'exit': {'kind': 'crossFade', 'duration': '0.5s'},
        'motionDefaults': {'ease': 'linear'},
        'children': [
          {'type': 'Text', 'text': 'x'},
        ],
      }, AnchorTable());
      expect(scene.build(AnchorTable()), isA<Scene>());
      expect(SceneSpec.fromJson(scene.toJson(), AnchorTable()).toJson(), scene.toJson());
    });

    test('rejects a malformed scene', () {
      expect(() => SceneSpec.fromJson(const {}, AnchorTable()), throwsA(isA<FluvieSpecError>()));
      expect(
        () => SceneSpec.fromJson(const {'duration': '1s', 'children': 'no'}, AnchorTable()),
        throwsA(isA<FluvieSpecError>()),
      );
      expect(
        () => SceneSpec.fromJson(const {
          'duration': '1s',
          'children': ['no'],
        }, AnchorTable()),
        throwsA(isA<FluvieSpecError>()),
      );
    });
  });
}
