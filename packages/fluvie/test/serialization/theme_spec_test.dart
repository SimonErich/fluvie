import 'package:flutter/painting.dart' show Color, FontWeight;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart'
    show
        Box,
        Defaults,
        Ease,
        ThemeSpec,
        Time,
        VideoSpec,
        decodeColor,
        decodeKeyframe,
        unknownSpecProps,
        videoSpecSchema;
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/serialization/codecs/text_style_codec.dart';

/// A representative full theme: two palette colors, one type-scale entry,
/// one spacing token, and composed motion defaults.
Map<String, Object?> _themeJson() => {
  'palette': {'accent': '#FF6C5CE7', 'surface': '#FF101018'},
  'typeScale': {
    'heading': {'color': '#FFF5F6FA', 'fontSize': 64, 'fontWeight': 'w700'},
  },
  'spacing': {'gutter': 24},
  'motion': {'duration': '12f', 'ease': 'out'},
};

Map<String, Object?> _document({
  Map<String, Object?>? theme,
  List<Map<String, Object?>> children = const [],
  Map<String, Object?>? background,
  Map<String, Object?>? motionDefaults,
}) => {
  'fluvieSpec': 1,
  'size': {'width': 480, 'height': 270},
  'fps': 30,
  'theme': ?theme,
  'motionDefaults': ?motionDefaults,
  'scenes': [
    {
      'duration': '60f',
      'layout': 'canvas',
      'background': ?background,
      'children': children,
    },
  ],
};

void main() {
  group('ThemeSpec parses and round-trips', () {
    test('a full theme round-trips identically', () {
      final theme = ThemeSpec.fromJson(_themeJson());
      expect(theme.toJson(), _themeJson());
      expect(theme.palette['accent'], const Color(0xFF6C5CE7));
      expect(theme.typeScale['heading']!.fontSize, 64);
      expect(theme.typeScale['heading']!.fontWeight, FontWeight.w700);
      expect(theme.spacing['gutter'], 24);
      expect(theme.motion, const Defaults(duration: Time.frames(12), ease: Ease.out));
    });

    test('an empty theme stays empty and elides its maps', () {
      final theme = ThemeSpec.fromJson(const {});
      expect(theme.toJson(), isEmpty);
      expect(theme.palette, isEmpty);
      expect(theme.typeScale, isEmpty);
      expect(theme.spacing, isEmpty);
      expect(theme.motion, isNull);
    });

    test('a token name must be an identifier', () {
      expect(
        () => ThemeSpec.fromJson(
          const {
            'palette': {'2bad': '#FF000000'},
          },
          path: const ['theme'],
        ),
        throwsA(
          isA<FluvieSpecError>().having((e) => e.message, 'message', contains('"2bad"')).having(
            (e) => e.path,
            'path',
            ['theme', 'palette'],
          ),
        ),
      );
      expect(
        () => ThemeSpec.fromJson(const {
          'spacing': {'has-dash': 8},
        }),
        throwsA(isA<FluvieSpecError>()),
      );
    });

    test('palette values are literal hex strings, never tokens', () {
      expect(
        () => ThemeSpec.fromJson(const {
          'palette': {
            'accent': {'token': 'other'},
          },
        }),
        throwsA(isA<FluvieSpecError>().having((e) => e.message, 'message', contains('literal'))),
      );
    });

    test('a type-scale style is literal: tokens cannot reference tokens', () {
      expect(
        () => ThemeSpec.fromJson(const {
          'typeScale': {
            'heading': {'token': 'body'},
          },
        }),
        throwsA(isA<FluvieSpecError>()),
      );
      expect(
        () => ThemeSpec.fromJson(const {
          'typeScale': {
            'heading': {
              'color': {'token': 'accent'},
            },
          },
        }),
        throwsA(isA<FluvieSpecError>().having((e) => e.message, 'message', contains('literal'))),
      );
    });

    test('a spacing value must be a number', () {
      expect(
        () => ThemeSpec.fromJson(const {
          'spacing': {'gutter': 'wide'},
        }),
        throwsA(isA<FluvieSpecError>()),
      );
    });

    test('each token map must be an object', () {
      expect(
        () => ThemeSpec.fromJson(const {'palette': 'accent'}),
        throwsA(
          isA<FluvieSpecError>().having((e) => e.message, 'message', contains('object')).having(
            (e) => e.path,
            'path',
            ['palette'],
          ),
        ),
      );
      expect(
        () => ThemeSpec.fromJson(const {
          'typeScale': {'heading': 'big'},
        }),
        throwsA(isA<FluvieSpecError>().having((e) => e.message, 'message', contains('style'))),
      );
    });

    test('the top-level theme must be an object', () {
      expect(
        () => VideoSpec.fromJson({..._document(), 'theme': 'dark'}),
        throwsA(
          isA<FluvieSpecError>().having((e) => e.message, 'message', contains('theme')).having(
            (e) => e.path,
            'path',
            ['theme'],
          ),
        ),
      );
    });
  });

  group('color tokens resolve at decode time', () {
    final theme = ThemeSpec.fromJson(_themeJson());

    test('a literal color stays untouched inside a theme scope', () {
      final color = ThemeSpec.resolve(theme, () => decodeColor('#FF00FF00'));
      expect(color, const Color(0xFF00FF00));
    });

    test('a token reference resolves against the palette', () {
      final color = ThemeSpec.resolve(theme, () => decodeColor(const {'token': 'accent'}));
      expect(color, const Color(0xFF6C5CE7));
    });

    test('an unknown token throws with the path and the known names', () {
      expect(
        () => ThemeSpec.resolve(
          theme,
          () => decodeColor(const {'token': 'primary'}, path: const ['color']),
        ),
        throwsA(
          isA<FluvieSpecError>()
              .having((e) => e.message, 'message', contains('"primary"'))
              .having((e) => e.message, 'message', contains('accent'))
              .having((e) => e.message, 'message', contains('surface'))
              .having((e) => e.path, 'path', ['color']),
        ),
      );
    });

    test('a token with no theme in scope throws loudly', () {
      expect(
        () => decodeColor(const {'token': 'accent'}, path: const ['color']),
        throwsA(isA<FluvieSpecError>().having((e) => e.message, 'message', contains('theme'))),
      );
    });

    test('a color token object is a closed shape', () {
      expect(
        () => ThemeSpec.resolve(theme, () => decodeColor(const {'token': 'accent', 'alpha': 0.5})),
        throwsA(isA<FluvieSpecError>()),
      );
      expect(() => decodeColor(const {'other': 'accent'}), throwsA(isA<FluvieSpecError>()));
    });

    test('an empty palette names itself honestly', () {
      expect(
        () => ThemeSpec.resolve(ThemeSpec(), () => decodeColor(const {'token': 'accent'})),
        throwsA(
          isA<FluvieSpecError>().having((e) => e.message, 'message', contains('no tokens')),
        ),
      );
    });

    test('a keyframe color token resolves at build time', () {
      final keyframe = ThemeSpec.resolve(
        theme,
        () => decodeKeyframe(const {
          'opacity': 1,
          'color': {'token': 'accent'},
        }),
      );
      expect(keyframe.color, const Color(0xFF6C5CE7));
    });
  });

  group('style tokens resolve from the type scale', () {
    final theme = ThemeSpec.fromJson(_themeJson());

    test('a bare style token adopts the whole type-scale entry', () {
      final style = ThemeSpec.resolve(theme, () => decodeTextStyle(const {'token': 'heading'}));
      expect(style.fontSize, 64);
      expect(style.fontWeight, FontWeight.w700);
      expect(style.color, const Color(0xFFF5F6FA));
    });

    test('a sibling literal field wins over the token per field', () {
      final style = ThemeSpec.resolve(
        theme,
        () => decodeTextStyle(const {'token': 'heading', 'fontSize': 90}),
      );
      expect(style.fontSize, 90, reason: 'the literal override wins');
      expect(style.fontWeight, FontWeight.w700, reason: 'unset fields keep the token value');
      expect(style.color, const Color(0xFFF5F6FA));
    });

    test('a sibling color may itself be a palette token', () {
      final style = ThemeSpec.resolve(
        theme,
        () => decodeTextStyle(const {
          'token': 'heading',
          'color': {'token': 'accent'},
        }),
      );
      expect(style.color, const Color(0xFF6C5CE7));
      expect(style.fontSize, 64);
    });

    test('an unknown style token throws with the known names', () {
      expect(
        () => ThemeSpec.resolve(
          theme,
          () => decodeTextStyle(const {'token': 'caption'}, path: const ['style']),
        ),
        throwsA(
          isA<FluvieSpecError>()
              .having((e) => e.message, 'message', contains('"caption"'))
              .having((e) => e.message, 'message', contains('heading'))
              .having((e) => e.path, 'path', ['style']),
        ),
      );
    });

    test('a style token with no theme in scope throws loudly', () {
      expect(
        () => decodeTextStyle(const {'token': 'heading'}),
        throwsA(isA<FluvieSpecError>().having((e) => e.message, 'message', contains('theme'))),
      );
    });

    test('a style token must be a string', () {
      expect(
        () => ThemeSpec.resolve(theme, () => decodeTextStyle(const {'token': 7})),
        throwsA(
          isA<FluvieSpecError>().having((e) => e.path, 'path', ['token']),
        ),
      );
    });
  });

  group('VideoSpec carries the theme through build and digest', () {
    test('the theme key parses, re-encodes, and joins knownKeys', () {
      final spec = VideoSpec.fromJson(_document(theme: _themeJson()));
      expect(spec.theme, isNotNull);
      expect(spec.toJson()['theme'], _themeJson());
      expect(VideoSpec.knownKeys, contains('theme'));
    });

    test('build resolves element color tokens against the document theme', () {
      final spec = VideoSpec.fromJson(
        _document(
          theme: _themeJson(),
          children: [
            {
              'type': 'Box',
              'color': {'token': 'accent'},
            },
          ],
        ),
      );
      final scene = spec.build().scenes.single;
      final box = scene.children.single as Box;
      expect(box.color, const Color(0xFF6C5CE7));
    });

    test('build resolves a background color token', () {
      final spec = VideoSpec.fromJson(
        _document(
          theme: _themeJson(),
          background: {
            'kind': 'color',
            'color': {'token': 'surface'},
          },
        ),
      );
      expect(spec.build().scenes.single.background, isNotNull);
      final unknown = VideoSpec.fromJson(
        _document(
          theme: _themeJson(),
          background: {
            'kind': 'color',
            'color': {'token': 'missing'},
          },
        ),
      );
      expect(
        unknown.build,
        throwsA(isA<FluvieSpecError>().having((e) => e.message, 'message', contains('"missing"'))),
        reason: 'an unknown background token proves the background decodes inside the scope',
      );
    });

    test('an unresolvable token fails the build with its document path', () {
      final spec = VideoSpec.fromJson(
        _document(
          children: [
            {
              'type': 'Box',
              'color': {'token': 'accent'},
            },
          ],
        ),
      );
      expect(
        spec.build,
        throwsA(isA<FluvieSpecError>().having((e) => e.message, 'message', contains('theme'))),
      );
    });

    test('a theme change moves the digest', () {
      final themed = VideoSpec.fromJson(_document(theme: _themeJson()));
      final retinted = _themeJson();
      (retinted['palette']! as Map<String, Object?>)['accent'] = '#FF00B894';
      expect(VideoSpec.fromJson(_document(theme: retinted)).digest(), isNot(themed.digest()));
      expect(VideoSpec.fromJson(_document()).digest(), isNot(themed.digest()));
    });

    test('theme motion composes under explicit motionDefaults per field', () {
      final themeOnly = VideoSpec.fromJson(_document(theme: _themeJson()));
      expect(
        themeOnly.effectiveMotionDefaults,
        const Defaults(duration: Time.frames(12), ease: Ease.out),
      );

      final overridden = VideoSpec.fromJson(
        _document(theme: _themeJson(), motionDefaults: {'duration': '30f'}),
      );
      expect(
        overridden.effectiveMotionDefaults,
        const Defaults(duration: Time.frames(30), ease: Ease.out),
        reason: 'the explicit duration wins; the ease falls through to the theme',
      );

      final unthemed = VideoSpec.fromJson(_document(motionDefaults: {'duration': '30f'}));
      expect(unthemed.effectiveMotionDefaults, const Defaults(duration: Time.frames(30)));
      expect(VideoSpec.fromJson(_document()).effectiveMotionDefaults, isNull);
      expect(themeOnly.build().motionDefaults, themeOnly.effectiveMotionDefaults);
    });

    test('the resolution scope restores the previous theme on exit', () {
      final outer = ThemeSpec.fromJson(const {
        'palette': {'accent': '#FF000001'},
      });
      final inner = ThemeSpec.fromJson(const {
        'palette': {'accent': '#FF000002'},
      });
      ThemeSpec.resolve(outer, () {
        expect(ThemeSpec.current, same(outer));
        ThemeSpec.resolve(inner, () => expect(ThemeSpec.current, same(inner)));
        expect(ThemeSpec.current, same(outer));
      });
      expect(ThemeSpec.current, isNull);
    });
  });

  group('validation keeps the theme shapes closed', () {
    test('an unknown key inside the theme warns', () {
      final warnings = unknownSpecProps(_document(theme: {'palete': <String, Object?>{}}));
      expect(warnings, hasLength(1));
      expect(warnings.single.path, ['theme']);
      expect(warnings.single.message, contains('"palete"'));
      expect(warnings.single.message, contains('palette'));
    });

    test('a type-scale entry is a closed literal style shape', () {
      final warnings = unknownSpecProps(
        _document(
          theme: {
            'typeScale': {
              'heading': {'fontSize': 64, 'fontWieght': 'w700'},
            },
          },
        ),
      );
      expect(warnings, hasLength(1));
      expect(warnings.single.path, ['theme', 'typeScale', 'heading']);
      expect(warnings.single.message, contains('fontWeight'));
    });

    test('a clean themed document with token references validates clean', () {
      final document = _document(
        theme: _themeJson(),
        children: [
          {
            'type': 'Text',
            'text': 'hi',
            'style': {'token': 'heading', 'fontSize': 90},
          },
          {
            'type': 'Box',
            'color': {'token': 'accent'},
          },
        ],
      );
      expect(unknownSpecProps(document), isEmpty);
    });
  });

  group('the schema advertises the theme vocabulary', () {
    Map<String, Object?> defs() =>
        (videoSpecSchema[r'$defs']! as Map<String, Object?>).cast<String, Object?>();

    test('the document root advertises the theme property', () {
      final properties = videoSpecSchema['properties']! as Map<String, Object?>;
      expect((properties['theme']! as Map<String, Object?>)[r'$ref'], r'#/$defs/theme');
    });

    test('the theme def is closed over the ThemeSpec keys', () {
      final theme = defs()['theme']! as Map<String, Object?>;
      expect(theme['additionalProperties'], isFalse);
      expect((theme['properties']! as Map<String, Object?>).keys.toSet(), ThemeSpec.knownKeys);
    });

    test('a color is a literal or a closed token reference', () {
      final color = defs()['color']! as Map<String, Object?>;
      final oneOf = (color['oneOf']! as List).cast<Map<String, Object?>>();
      expect(oneOf, hasLength(2));
      expect(oneOf.first[r'$ref'], r'#/$defs/colorLiteral');
      expect(oneOf.last[r'$ref'], r'#/$defs/colorToken');
      final token = defs()['colorToken']! as Map<String, Object?>;
      expect(token['additionalProperties'], isFalse);
      expect(token['required'], ['token']);
    });

    test('a text style takes an optional type-scale token; the literal def does not', () {
      final style = defs()['textStyle']! as Map<String, Object?>;
      expect((style['properties']! as Map<String, Object?>).keys, contains('token'));
      final literal = defs()['textStyleLiteral']! as Map<String, Object?>;
      expect((literal['properties']! as Map<String, Object?>).keys, isNot(contains('token')));
      final typeScale =
          ((defs()['theme']! as Map<String, Object?>)['properties']!
              as Map<String, Object?>)['typeScale']!;
      expect(
        (typeScale as Map<String, Object?>)['additionalProperties'],
        {r'$ref': r'#/$defs/textStyleLiteral'},
      );
    });
  });

  group('spacing tokens are data-only this epic', () {
    test('spacing stores, round-trips, and moves the digest; nothing resolves it', () {
      final spec = VideoSpec.fromJson(_document(theme: _themeJson()));
      expect(spec.theme!.spacing, {'gutter': 24.0});
      final widened = _themeJson();
      (widened['spacing']! as Map<String, Object?>)['gutter'] = 32;
      expect(VideoSpec.fromJson(_document(theme: widened)).digest(), isNot(spec.digest()));
    });
  });

  group('scene builds outside a video still work without tokens', () {
    test('an unthemed scene with literals builds directly', () {
      final spec = VideoSpec.fromJson(
        _document(
          children: [
            {'type': 'Box', 'color': '#FF123456'},
          ],
        ),
      );
      final scene = spec.scenes.single;
      final built = scene.build(spec.anchors);
      expect((built.children.single as Box).color, const Color(0xFF123456));
    });
  });
}
