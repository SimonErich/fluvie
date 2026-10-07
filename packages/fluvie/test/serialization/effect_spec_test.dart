// An element's effect stack: an ordered list of named pixel and transform
// effects that wrap it. Declared once, applied every frame, and ordered by
// class rather than by list position so a stack reads the same however it
// was typed.

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

Map<String, Object?> _deck({List<Object?>? effects}) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'children': [
        {'id': 'el-a', 'type': 'Text', 'text': 'one', 'effects': ?effects},
      ],
    },
  ],
};

VideoSpec _spec(Map<String, Object?> json) => VideoSpec.fromJson(json);

ElementSpec _element(Map<String, Object?> json) => _spec(json).scenes.single.children.single;

void main() {
  group('the stack', () {
    test('reads its effects in order', () {
      final element = _element(
        _deck(
          effects: [
            {'kind': 'grain', 'amount': 0.4},
            {'kind': 'vignette', 'amount': 0.6},
          ],
        ),
      );

      expect(element.effects, hasLength(2));
      expect(element.effects.first.kind, EffectSpecKind.grain);
      expect(element.effects.first.params['amount'], 0.4);
      expect(element.effects.last.kind, EffectSpecKind.vignette);
    });

    test('is empty on an element that declares none', () {
      expect(_element(_deck()).effects, isEmpty);
    });

    test('defaults enabled to true, because a declared effect is meant to run', () {
      final element = _element(
        _deck(
          effects: [
            {'kind': 'grain'},
          ],
        ),
      );

      expect(element.effects.single.enabled, isTrue);
    });

    test('keeps a disabled effect in the document', () {
      // Like `visible: false`: the author turned it off, they did not delete
      // it, and a round-trip that dropped it would lose their work.
      final element = _element(
        _deck(
          effects: [
            {'kind': 'grain', 'enabled': false, 'amount': 0.4},
          ],
        ),
      );

      expect(element.effects.single.enabled, isFalse);
      expect(element.effects.single.params['amount'], 0.4);
    });

    test('round-trips, and an element without one grows no key', () {
      final effects = [
        {'kind': 'grain', 'amount': 0.4},
        {'kind': 'scanlines', 'spacing': 4.0, 'opacity': 0.2},
      ];
      final json = _spec(_deck(effects: effects)).toJson();
      final child =
          ((json['scenes']! as List<Object?>).single! as Map<String, Object?>)['children']!
              as List<Object?>;

      expect((child.single! as Map<String, Object?>)['effects'], effects);
      expect(VideoSpec.fromJson(json).toJson(), json);
      expect(
        (((_spec(_deck()).toJson()['scenes']! as List<Object?>).single!
                        as Map<String, Object?>)['children']!
                    as List<Object?>)
                .single!
            as Map<String, Object?>,
        isNot(contains('effects')),
      );
    });

    test('counts into the digest, because it changes pixels', () {
      expect(
        _spec(
          _deck(
            effects: [
              {'kind': 'grain', 'amount': 0.4},
            ],
          ),
        ).digest(),
        isNot(_spec(_deck()).digest()),
      );
    });

    test('never lands in the props map', () {
      // A reserved key that leaked into props would be handed to the widget
      // as content, and a Text with a stray `effects` prop is a different Text.
      final element = _element(
        _deck(
          effects: [
            {'kind': 'grain'},
          ],
        ),
      );

      expect(element.props.containsKey('effects'), isFalse);
    });
  });

  group('what it refuses', () {
    test('a kind it does not know', () {
      expect(
        () => _spec(
          _deck(
            effects: [
              {'kind': 'kaleidoscope'},
            ],
          ),
        ),
        throwsA(isA<FluvieSpecError>()),
      );
    });

    test('an effect with no kind at all', () {
      expect(
        () => _spec(_deck(effects: [<String, Object?>{}])),
        throwsA(isA<FluvieSpecError>()),
      );
    });

    test('something that is not an object', () {
      expect(() => _spec(_deck(effects: ['grain'])), throwsA(isA<FluvieSpecError>()));
    });

    test('an effects value that is not a list', () {
      expect(
        () => _spec({
          'fluvieSpec': 1,
          'fps': 30,
          'scenes': [
            {
              'duration': '60f',
              'children': [
                {'id': 'el-a', 'type': 'Text', 'text': 'one', 'effects': 'grain'},
              ],
            },
          ],
        }),
        throwsA(isA<FluvieSpecError>()),
      );
    });

    test('a parameter outside its honest range', () {
      // Grain is a `[0, 1]` strength. A 5 is not a stronger grain, it is a
      // number the effect will silently clamp — so the document says so
      // instead of rendering something the author did not write.
      expect(
        () => _spec(
          _deck(
            effects: [
              {'kind': 'grain', 'amount': 5},
            ],
          ),
        ),
        throwsA(isA<FluvieSpecError>()),
      );
    });

    test('a parameter of the wrong type', () {
      expect(
        () => _spec(
          _deck(
            effects: [
              {'kind': 'grain', 'amount': 'lots'},
            ],
          ),
        ),
        throwsA(isA<FluvieSpecError>()),
      );
    });

    test('a parameter the effect does not have', () {
      expect(
        () => _spec(
          _deck(
            effects: [
              {'kind': 'grain', 'wobble': 2},
            ],
          ),
        ),
        throwsA(isA<FluvieSpecError>()),
      );
    });
  });

  group('every kind Fluvie knows', () {
    test('parses with no parameters at all, on its own defaults', () {
      for (final kind in EffectSpecKind.values) {
        expect(
          () => _spec(
            _deck(
              effects: [
                {'kind': kind.name, ...?_requiredFor(kind)},
              ],
            ),
          ),
          returnsNormally,
          reason: kind.name,
        );
      }
    });

    test('declares whether it is a transform or a pixel effect', () {
      // The order the stack composes in is a property of the kind, not of
      // where the author happened to type it.
      expect(EffectSpecKind.parallax.isPixel, isFalse);
      expect(EffectSpecKind.grain.isPixel, isTrue);
    });
  });

  group('the colour kinds', () {
    test('curves parses its channels and builds the curved effect', () {
      final element = _element(
        _deck(
          effects: [
            {
              'kind': 'curves',
              'curves': {
                'master': [
                  [0, 0],
                  [0.5, 0.6],
                  [1, 1],
                ],
                'red': [
                  [0, 0.1],
                  [1, 0.9],
                ],
              },
              'intensity': 0.8,
            },
          ],
        ),
      );

      final effect = element.effects.single;
      expect(effect.kind, EffectSpecKind.curves);
      expect(effect.number('intensity'), 0.8);
      expect(effect.object('curves')!['master'], hasLength(3));
    });

    test('lut carries its asset and intensity', () {
      final effect = _element(
        _deck(
          effects: [
            {'kind': 'lut', 'asset': 'luts/warm.cube', 'intensity': 0.6},
          ],
        ),
      ).effects.single;

      expect(effect.kind, EffectSpecKind.lut);
      expect(effect.text('asset'), 'luts/warm.cube');
      expect(effect.number('intensity'), 0.6);
    });

    test('a lut asset is narrowed like every other asset the spec names', () {
      EffectSpec lut(String asset) => _element(
        _deck(
          effects: [
            {'kind': 'lut', 'asset': asset},
          ],
        ),
      ).effects.single;

      for (final hostile in ['/etc/passwd', '../secrets.cube', r'..\up.cube', 'http://x/a.cube']) {
        expect(() => buildEffect(lut(hostile)), throwsA(isA<FluvieSpecError>()), reason: hostile);
      }
      expect(buildEffect(lut('luts/warm.cube')), isA<AnimationEffect>());
    });

    test('a lut with no asset yet grades nothing, so the editor can add-then-name', () {
      const child = SizedBox.shrink();
      final effect = buildEffect(
        _element(
          _deck(
            effects: [
              {'kind': 'lut'},
            ],
          ),
        ).effects.single,
      );

      expect(identical(effect.build(child, 0), child), isTrue);
    });

    test('curves content is validated when the effect builds, like particles', () {
      // The document parses (an object param is checked for being one); the
      // content faces its own rules at build, with a located error.
      EffectSpec spec(Map<String, Object?> curves) => _element(
        _deck(
          effects: [
            {'kind': 'curves', 'curves': curves},
          ],
        ),
      ).effects.single;

      expect(
        () => buildEffect(spec({'master': 'steep'})),
        throwsA(isA<FluvieSpecError>()),
      );
      expect(
        () => buildEffect(
          spec({
            'alpha': [
              [0, 0],
              [1, 1],
            ],
          }),
        ),
        throwsA(isA<FluvieSpecError>()),
      );
      expect(
        () => buildEffect(
          spec({
            'master': [
              [0, 0],
            ],
          }),
        ),
        throwsA(isA<FluvieSpecError>()),
      );
    });
  });

  group('a live keyframed value', () {
    // The widget-authored twin of the JSON ramp: what printed Dart carries,
    // so a document converted to code keeps its motion.
    KeyframedNumber live() => KeyframedNumber.linear(
      values: const [0, 0.9],
      positions: const [Time.zero, Time.frames(60)],
    );

    test('answers everywhere its JSON twin does', () {
      final effect = EffectSpec(EffectSpecKind.grain, params: {'amount': live()});

      expect(effect.isKeyframed('amount'), isTrue);
      expect(effect.keyframed('amount')!.values, [0, 0.9]);
      expect(effect.varies, isTrue);
      expect(
        effect.number('amount', frame: (progress: 0.5, fps: 30, windowFrames: 60)),
        closeTo(0.45, 1e-9),
      );
    });

    test('writes the JSON its map twin would', () {
      final json = EffectSpec(EffectSpecKind.grain, params: {'amount': live()}).toJson();

      expect(json['amount'], {
        'values': [0.0, 0.9],
        'positions': ['0f', '60f'],
      });
      expect(VideoSpec.fromJson(_deck(effects: [json])), isA<VideoSpec>());
    });
  });

  group('what cannot be keyframed', () {
    test('an object parameter is never keyframed, whatever keys its map has', () {
      // A shader author is free to name a uniform "values"; that names a
      // float slot, not a ramp, and nothing downstream may mistake it.
      final effect = _element(
        _deck(
          effects: [
            {
              'kind': 'shader',
              'asset': 'shaders/warp.frag',
              'uniforms': {
                'values': 1.0,
              },
            },
          ],
        ),
      ).effects.single;

      expect(effect.isKeyframed('uniforms'), isFalse);
      expect(effect.keyframed('uniforms'), isNull);
      expect(effect.varies, isFalse);
      expect(effect.object('uniforms'), {
        'values': 1.0,
      });
    });
  });

  group('a keyframed parameter', () {
    Map<String, Object?> ramp() => {
      'kind': 'grain',
      'amount': {
        'values': [0, 0.9],
        'positions': ['0f', '60f'],
      },
    };

    test('parses beside a plain one', () {
      final element = _element(_deck(effects: [ramp()]));

      expect(element.effects.single.isKeyframed('amount'), isTrue);
      expect(element.effects.single.keyframed('amount')!.values, [0, 0.9]);
    });

    test('reads its value off the frame', () {
      final effect = _element(_deck(effects: [ramp()])).effects.single;

      expect(effect.number('amount', frame: (progress: 0, fps: 30, windowFrames: 60)), 0);
      expect(
        effect.number('amount', frame: (progress: 0.5, fps: 30, windowFrames: 60)),
        closeTo(0.45, 1e-9),
      );
      expect(effect.number('amount', frame: (progress: 1, fps: 30, windowFrames: 60)), 0.9);
    });

    test('says a plain number is not keyframed', () {
      final effect = _element(
        _deck(
          effects: [
            {'kind': 'grain', 'amount': 0.4},
          ],
        ),
      ).effects.single;

      expect(effect.isKeyframed('amount'), isFalse);
      expect(effect.keyframed('amount'), isNull);
      expect(effect.varies, isFalse);
    });

    test('marks the effect as varying, so the stack rebuilds it per frame', () {
      expect(_element(_deck(effects: [ramp()])).effects.single.varies, isTrue);
    });

    test('round-trips exactly', () {
      final json = _spec(_deck(effects: [ramp()])).toJson();

      expect(VideoSpec.fromJson(json).toJson(), json);
    });

    test('faces the same range a literal would, stop by stop', () {
      // A ramp to 5 is as wrong as a 5: the range is the effect's, not the
      // literal's.
      expect(
        () => _spec(
          _deck(
            effects: [
              {
                'kind': 'grain',
                'amount': {
                  'values': [0, 5],
                  'positions': ['0f', '60f'],
                },
              },
            ],
          ),
        ),
        throwsA(isA<FluvieSpecError>()),
      );
    });

    test('refuses a shape that is neither a number nor a keyframed value', () {
      expect(
        () => _spec(
          _deck(
            effects: [
              {'kind': 'grain', 'amount': <String, Object?>{}},
            ],
          ),
        ),
        throwsA(isA<FluvieSpecError>()),
      );
    });
  });
}

/// The parameters a kind cannot do without.
Map<String, Object?>? _requiredFor(EffectSpecKind kind) => switch (kind) {
  EffectSpecKind.shader => {'asset': 'shaders/glow.frag'},
  _ => null,
};
