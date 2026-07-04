import 'package:dart_style/dart_style.dart';
import 'package:fluvie_cli/src/codegen/dart_spec_printer.dart';
import 'package:test/test.dart';

/// A one-scene spec carrying [children], with a fixed square size.
Map<String, Object?> _spec(List<Map<String, Object?>> children, {Object? size = 'square'}) => {
  'fluvieSpec': 1,
  'size': ?size,
  'fps': 30,
  'scenes': [
    {
      'duration': '4.0s',
      'children': children,
    },
  ],
};

/// A single Text element with [text] and no animations.
Map<String, Object?> _text(String text, {Map<String, Object?>? style}) => {
  'type': 'Text',
  'text': text,
  'style': ?style,
};

/// Strips whitespace and `dart_style`'s wrap-only trailing commas so a code
/// fragment matches regardless of how the formatter line-wraps it.
String _canon(String code) =>
    code.replaceAll(RegExp(r'\s+'), '').replaceAll(',)', ')').replaceAll(',]', ']');

/// Matches when [fragment] appears in the code ignoring formatting (line wraps,
/// indentation, and trailing commas).
Matcher containsCode(String fragment) => predicate<String>(
  (code) => _canon(code).contains(_canon(fragment)),
  'contains code `$fragment` (ignoring formatting)',
);

void main() {
  const preamble =
      "import 'package:flutter/material.dart' hide Animation, Clip, Image, Tween;\n"
      "import 'package:fluvie/fluvie.dart';\n"
      '\n'
      'Video build() {';

  group('preamble and shape', () {
    test('emits the canonical import block and a Video build()', () {
      final code = printVideoSpecJson(_spec([_text('Hello, Fluvie')]));
      expect(code, startsWith(preamble));
      expect(code, contains('return Video('));
      expect(code, contains('Scene('));
      expect(code, contains('duration: 4.seconds'));
      expect(code, contains("Text('Hello, Fluvie')"));
    });

    test('output is already dart_style-formatted (stable under reformat)', () {
      final code = printVideoSpecJson(_spec([_text('Hi')]));
      final reformatted = DartFormatter(
        languageVersion: DartFormatter.latestLanguageVersion,
        pageWidth: 100,
      ).format(code);
      expect(code, reformatted);
    });
  });

  group('video-level fields', () {
    test('square size preset', () {
      expect(printVideoSpecJson(_spec([_text('x')])), contains('size: VideoSize.square'));
    });

    test('explicit dimensions', () {
      final code = printVideoSpecJson(_spec([_text('x')], size: {'width': 1280, 'height': 720}));
      expect(code, contains('size: VideoSize(1280, 720)'));
    });

    test('non-default fps is emitted, default fps omitted', () {
      final withFps = {
        ..._spec([_text('x')]),
        'fps': 60,
      };
      expect(printVideoSpecJson(withFps), contains('fps: 60'));
      expect(printVideoSpecJson(_spec([_text('x')])), isNot(contains('fps:')));
    });

    test('poster, export and motionDefaults', () {
      final spec = {
        ..._spec([_text('x')]),
        'poster': '1.0s',
        'export': {'mode': 'mp4', 'quality': 'high'},
        'motionDefaults': {'duration': '0.4s', 'ease': 'smooth'},
      };
      final code = printVideoSpecJson(spec);
      expect(code, contains('poster: 1.seconds'));
      expect(code, contains('export: Export.mp4(quality: Quality.high)'));
      expect(code, contains('motionDefaults: Defaults(duration: 0.4.seconds, ease: Ease.smooth)'));
    });

    test('video-level transition', () {
      final spec = {
        ..._spec([_text('x')]),
        'transition': {'kind': 'crossFade', 'duration': '0.5s', 'overlap': true, 'ease': 'linear'},
      };
      expect(
        printVideoSpecJson(spec),
        containsCode(
          'transition: Transition.crossFade(0.5.seconds, overlap: true, ease: Ease.linear)',
        ),
      );
    });
  });

  group('elements', () {
    test('Text with a full style', () {
      final code = printVideoSpecJson(
        _spec([
          _text('Title', style: {'color': '#FFFFFFFF', 'fontSize': 72, 'fontWeight': 'w700'}),
        ]),
      );
      expect(
        code,
        containsCode(
          "Text('Title', style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 72, "
          'fontWeight: FontWeight.w700))',
        ),
      );
    });

    test('Box with color and size', () {
      final code = printVideoSpecJson(
        _spec([
          {
            'type': 'Box',
            'color': '#FFFF0000',
            'size': {'width': 0.5, 'height': 0.01},
          },
        ]),
      );
      expect(code, contains('Box(color: Color(0xFFFF0000), size: Size(0.5, 0.01))'));
    });

    test('Image variants with and without fit', () {
      final asset = printVideoSpecJson(
        _spec([
          {
            'type': 'Image',
            'source': {'kind': 'asset', 'value': 'swatch.png'},
            'fit': 'cover',
          },
        ]),
      );
      expect(asset, contains("Image.asset('swatch.png', fit: BoxFit.cover)"));

      final network = printVideoSpecJson(
        _spec([
          {
            'type': 'Image',
            'source': {'kind': 'network', 'value': 'https://x/y.png'},
          },
        ]),
      );
      expect(network, contains("Image.network('https://x/y.png')"));
      expect(network, isNot(contains('fit:')));

      final file = printVideoSpecJson(
        _spec([
          {
            'type': 'Image',
            'source': {'kind': 'file', 'value': '/tmp/a.png'},
          },
        ]),
      );
      expect(file, contains("Image.file('/tmp/a.png')"));
    });

    test('Counter with from, duration and style', () {
      final code = printVideoSpecJson(
        _spec([
          {
            'type': 'Counter',
            'to': 12500,
            'from': 100,
            'duration': '2.0s',
            'style': {'fontSize': 48},
          },
        ]),
      );
      expect(
        code,
        containsCode(
          'Counter(to: 12500, from: 100, duration: 2.seconds, style: TextStyle(fontSize: 48))',
        ),
      );
    });

    test('Counter omits a default from of 0', () {
      final code = printVideoSpecJson(
        _spec([
          {'type': 'Counter', 'to': 9},
        ]),
      );
      expect(code, contains('Counter(to: 9)'));
    });
  });

  group('backgrounds', () {
    Map<String, Object?> sceneWith(Map<String, Object?> background) => {
      'fluvieSpec': 1,
      'size': 'square',
      'fps': 30,
      'scenes': [
        {
          'duration': '2.0s',
          'background': background,
          'children': [_text('x')],
        },
      ],
    };

    test('color', () {
      expect(
        printVideoSpecJson(sceneWith({'kind': 'color', 'color': '#FF112233'})),
        contains('background: Background.color(Color(0xFF112233))'),
      );
    });

    test('gradient with begin and end', () {
      final code = printVideoSpecJson(
        sceneWith({
          'kind': 'gradient',
          'colors': ['#FF1A2980', '#FF26D0CE'],
          'begin': 'topLeft',
          'end': 'bottomRight',
        }),
      );
      expect(
        code,
        containsCode(
          'Background.gradient([Color(0xFF1A2980), Color(0xFF26D0CE)], '
          'begin: Alignment.topLeft, end: Alignment.bottomRight)',
        ),
      );
    });

    test('radial', () {
      expect(
        printVideoSpecJson(
          sceneWith({
            'kind': 'radial',
            'colors': ['#FF000000', '#FFFFFFFF'],
          }),
        ),
        contains('Background.radial([Color(0xFF000000), Color(0xFFFFFFFF)])'),
      );
    });

    test('image with fit', () {
      expect(
        printVideoSpecJson(sceneWith({'kind': 'image', 'source': 'bg.png', 'fit': 'contain'})),
        contains("Background.image('bg.png', fit: BoxFit.contain)"),
      );
    });

    test('video', () {
      expect(
        printVideoSpecJson(sceneWith({'kind': 'video', 'source': 'clip.mp4'})),
        contains("Background.video('clip.mp4')"),
      );
    });

    test('noise with scale', () {
      expect(
        printVideoSpecJson(sceneWith({'kind': 'noise', 'scale': 2})),
        contains('Background.noise(scale: 2)'),
      );
    });

    test('vhs', () {
      expect(
        printVideoSpecJson(sceneWith({'kind': 'vhs'})),
        contains('Background.vhs()'),
      );
    });
  });

  group('animations', () {
    String codeFor(List<Map<String, Object?>> animate) => printVideoSpecJson(
      _spec([
        {'type': 'Text', 'text': 'x', 'animate': animate},
      ]),
    );

    test('fadeIn and pop on one element', () {
      expect(
        codeFor([
          {'preset': 'fadeIn'},
          {'preset': 'pop'},
        ]),
        contains('.animate([Animation.fadeIn(), Animation.pop()])'),
      );
    });

    test('slideIn carries its from edge', () {
      expect(
        codeFor([
          {'preset': 'slideIn', 'from': 'left'},
        ]),
        contains('Animation.slideIn(from: Edge.left)'),
      );
    });

    test('pop overshoot and full timing tail', () {
      final code = codeFor([
        {
          'preset': 'pop',
          'overshoot': 1.2,
          'duration': '0.3s',
          'ease': 'snappy',
          'spring': 'gentle',
          'delay': '100ms',
          'stagger': {'each': '40ms'},
          'repeat': {'forever': true, 'yoyo': true},
          'label': 'hero',
        },
      ]);
      expect(
        code,
        containsCode(
          'Animation.pop(overshoot: 1.2, duration: 0.3.seconds, ease: Ease.snappy, '
          'spring: Spring.gentle, delay: 100.ms, stagger: Stagger.each(40.ms), '
          "repeat: Repeat.forever(yoyo: true), label: 'hero')",
        ),
      );
    });

    test('grain takes its amount positionally', () {
      expect(
        codeFor([
          {'preset': 'grain', 'amount': 0.3},
        ]),
        contains('Animation.grain(0.3)'),
      );
    });

    test('ambient spin emits no duration or ease', () {
      final code = codeFor([
        {'preset': 'spin', 'per': '2.0s', 'duration': '5.0s', 'ease': 'smooth'},
      ]);
      expect(code, contains('Animation.spin(per: 2.seconds)'));
      expect(code, isNot(contains('Ease.smooth')));
    });

    test('raw fromTo with keyframes', () {
      expect(
        codeFor([
          {
            'from': {'opacity': 0, 'y': 0.3},
            'to': {'opacity': 1, 'y': 0},
          },
        ]),
        containsCode(
          'Animation.fromTo(Keyframe(opacity: 0, y: 0.3), Keyframe(opacity: 1, y: 0))',
        ),
      );
    });
  });

  group('literals', () {
    String timeCode(String t) => printVideoSpecJson({
      'fluvieSpec': 1,
      'size': 'square',
      'fps': 30,
      'scenes': [
        {
          'duration': t,
          'children': [_text('x')],
        },
      ],
    });

    test('frames, milliseconds and capped relative', () {
      expect(timeCode('30f'), contains('duration: 30.frames'));
      expect(timeCode('500ms'), contains('duration: 500.ms'));
      expect(timeCode('0.3r'), contains('duration: 0.3.relative'));
      expect(timeCode('0.2r@0.8s'), contains('duration: Time.relative(0.2, max: 0.8.seconds)'));
    });

    test('the in ease maps to Ease.in_', () {
      final code = printVideoSpecJson(
        _spec([
          {
            'type': 'Text',
            'text': 'x',
            'animate': [
              {'preset': 'fadeIn', 'ease': 'in'},
            ],
          },
        ]),
      );
      expect(code, contains('ease: Ease.in_'));
    });
  });

  group('anchors (identity)', () {
    test('declares each anchor once and reuses the variable', () {
      final spec = {
        'fluvieSpec': 1,
        'size': 'square',
        'fps': 30,
        'scenes': [
          {
            'duration': '4.0s',
            'children': [
              {
                'type': 'Text',
                'text': 'Title',
                'anchor': 'intro',
                'animate': [
                  {'preset': 'pop'},
                ],
              },
              {
                'type': 'Text',
                'text': 'Sub',
                'animate': [
                  {
                    'preset': 'fadeIn',
                    'at': {'kind': 'whenEnds', 'anchor': 'intro'},
                  },
                ],
              },
            ],
          },
        ],
      };
      final code = printVideoSpecJson(spec);
      expect(code, contains("final intro = Anchor('intro');"));
      // Declared exactly once.
      expect("Anchor('intro')".allMatches(code).length, 1);
      expect(code, contains('anchor: intro'));
      expect(code, contains('Animation.fadeIn(at: Trigger.whenEnds(intro))'));
    });
  });

  group('security: string escaping', () {
    test('neutralizes quotes, interpolation and statement breaks in text', () {
      const evil = r"'); badCode(); Text('$x ${y()}";
      final code = printVideoSpecJson(_spec([_text(evil)]));
      // Every dangerous character is escaped, so the payload stays inert inside
      // one literal: the closing quote, simple interpolation, and an expression
      // interpolation are all neutralized.
      expect(code, contains(r"\');"));
      expect(code, contains(r'\$x'));
      expect(code, contains(r'\${y()}'));
      // The escaped result is still valid, stable Dart (a broken-out payload
      // would make this throw).
      final reformatted = DartFormatter(
        languageVersion: DartFormatter.latestLanguageVersion,
        pageWidth: 100,
      ).format(code);
      expect(reformatted, code);
    });

    test('escapes backslashes and newlines', () {
      final code = printVideoSpecJson(_spec([_text('a\\b\nc')]));
      expect(code, contains(r"Text('a\\b\nc')"));
    });
  });
}
