import 'package:fluvie_cli/src/codegen/dart_spec_printer.dart';
import 'package:test/test.dart';

/// Strips whitespace and wrap-only trailing commas so a fragment matches
/// regardless of how dart_style line-wraps it.
String _canon(String code) =>
    code.replaceAll(RegExp(r'\s+'), '').replaceAll(',)', ')').replaceAll(',]', ']');

Matcher containsCode(String fragment) => predicate<String>(
  (code) => _canon(code).contains(_canon(fragment)),
  'contains code `$fragment` (ignoring formatting)',
);

/// One scene around [children], with optional extra scene-level [scene] keys.
Map<String, Object?> _wrap(
  List<Map<String, Object?>> children, {
  Map<String, Object?> scene = const {},
}) => {
  'fluvieSpec': 1,
  'size': 'square',
  'fps': 30,
  'scenes': [
    {'duration': '2.0s', ...scene, 'children': children},
  ],
};

/// A one-animation Text element rendered to code.
String _anim(Map<String, Object?> animation) => printVideoSpecJson(
  _wrap([
    {
      'type': 'Text',
      'text': 'x',
      'animate': [animation],
    },
  ]),
);

void main() {
  group('animation presets (remaining)', () {
    test('fadeOut, slideOut, slideFade, scaleIn, blurIn, blurOut', () {
      expect(_anim({'preset': 'fadeOut'}), containsCode('Animation.fadeOut()'));
      expect(
        _anim({'preset': 'slideOut', 'to': 'top'}),
        containsCode('Animation.slideOut(to: Edge.top)'),
      );
      expect(
        _anim({'preset': 'slideFade', 'from': 'right'}),
        containsCode('Animation.slideFade(from: Edge.right)'),
      );
      expect(
        _anim({'preset': 'scaleIn', 'from': 0.9}),
        containsCode('Animation.scaleIn(from: 0.9)'),
      );
      expect(_anim({'preset': 'blurIn', 'sigma': 8}), containsCode('Animation.blurIn(sigma: 8)'));
      expect(_anim({'preset': 'blurOut', 'sigma': 6}), containsCode('Animation.blurOut(sigma: 6)'));
    });

    test('vignette positional, drift and kenBurns ambient', () {
      expect(_anim({'preset': 'vignette', 'amount': 0.4}), containsCode('Animation.vignette(0.4)'));
      expect(
        _anim({'preset': 'drift', 'to': 'right', 'distance': 0.2}),
        containsCode('Animation.drift(to: Edge.right, distance: 0.2)'),
      );
      expect(
        _anim({'preset': 'kenBurns', 'zoom': 1.2, 'pan': 'left'}),
        containsCode('Animation.kenBurns(zoom: 1.2, pan: Edge.left)'),
      );
    });

    test('grain with no amount defaults to 0', () {
      expect(_anim({'preset': 'grain'}), containsCode('Animation.grain(0)'));
    });

    test('raw from and raw to', () {
      expect(
        _anim({
          'from': {'opacity': 0},
        }),
        containsCode('Animation.from(Keyframe(opacity: 0))'),
      );
      expect(
        _anim({
          'to': {'scale': 1},
        }),
        containsCode('Animation.to(Keyframe(scale: 1))'),
      );
    });

    test('keyframe with color and origin', () {
      expect(
        _anim({
          'from': {'scale': 0, 'color': '#FFFF0000', 'origin': 'topLeft'},
        }),
        containsCode('Keyframe(scale: 0, color: Color(0xFFFF0000), origin: Alignment.topLeft)'),
      );
    });
  });

  group('triggers', () {
    test('keyword triggers', () {
      for (final keyword in ['sceneStart', 'sceneEnd', 'previous', 'auto']) {
        expect(_anim({'preset': 'fadeIn', 'at': keyword}), containsCode('at: Trigger.$keyword'));
      }
    });

    test('absolute and beat triggers', () {
      expect(
        _anim({
          'preset': 'fadeIn',
          'at': {'kind': 'at', 'time': '1.0s'},
        }),
        containsCode('at: Trigger.at(1.seconds)'),
      );
      expect(
        _anim({
          'preset': 'fadeIn',
          'at': {'kind': 'beat', 'every': 2},
        }),
        containsCode('at: Trigger.beat(every: 2)'),
      );
    });

    test('whenStarts and beat-with-track reuse anchor variables', () {
      final code = printVideoSpecJson(
        _wrap([
          {
            'type': 'Text',
            'text': 'a',
            'anchor': 'beat',
            'animate': [
              {'preset': 'fadeIn'},
            ],
          },
          {
            'type': 'Text',
            'text': 'b',
            'animate': [
              {
                'preset': 'fadeIn',
                'at': {'kind': 'whenStarts', 'anchor': 'beat'},
              },
            ],
          },
          {
            'type': 'Text',
            'text': 'c',
            'animate': [
              {
                'preset': 'fadeIn',
                'at': {'kind': 'beat', 'every': 1, 'track': 'beat'},
              },
            ],
          },
        ]),
      );
      expect(code, containsCode('Trigger.whenStarts(beat)'));
      expect(code, containsCode('track: beat'));
    });
  });

  group('motion objects', () {
    test('spring object form', () {
      expect(
        _anim({
          'preset': 'pop',
          'spring': {'stiffness': 200, 'damping': 10, 'mass': 1, 'initialVelocity': 0},
        }),
        containsCode('spring: Spring(stiffness: 200, damping: 10, mass: 1, initialVelocity: 0)'),
      );
    });

    test('stagger evenly and from', () {
      expect(
        _anim({
          'preset': 'fadeIn',
          'stagger': {'evenly': '1.0s'},
        }),
        containsCode('stagger: Stagger.evenly(over: 1.seconds)'),
      );
      expect(
        _anim({
          'preset': 'fadeIn',
          'stagger': {'from': 'center', 'gap': '50ms'},
        }),
        containsCode('stagger: Stagger.from(StaggerOrigin.center, gap: 50.ms)'),
      );
    });

    test('repeat forever without yoyo and counted times', () {
      expect(
        _anim({
          'preset': 'fadeIn',
          'repeat': {'forever': true},
        }),
        containsCode('Repeat.forever()'),
      );
      expect(
        _anim({
          'preset': 'fadeIn',
          'repeat': {'times': 3, 'yoyo': true, 'gap': '100ms'},
        }),
        containsCode('repeat: Repeat.times(3, yoyo: true, gap: 100.ms)'),
      );
    });
  });

  group('scene fields and transitions', () {
    test('scene enter/exit/motionDefaults and empty children', () {
      final code = printVideoSpecJson(
        _wrap(
          [],
          scene: {
            'enter': {
              'kind': 'wipe',
              'duration': '0.4s',
              'direction': 'right',
              'overlap': true,
              'ease': 'linear',
            },
            'exit': {
              'kind': 'zoom',
              'duration': '0.3s',
              'into': 'center',
              'overlap': false,
              'ease': 'smooth',
            },
            'motionDefaults': {'duration': '0.2s'},
          },
        ),
      );
      expect(code, containsCode('enter: Transition.wipe(0.4.seconds, direction: Edge.right'));
      expect(code, containsCode('exit: Transition.zoom(0.3.seconds, into: Alignment.center'));
      expect(code, containsCode('motionDefaults: Defaults(duration: 0.2.seconds)'));
      expect(code, isNot(contains('children:')));
    });

    test('slide transition and cut', () {
      expect(
        printVideoSpecJson(
          _wrap(
            [
              {'type': 'Text', 'text': 'x'},
            ],
            scene: {
              'enter': {
                'kind': 'slide',
                'duration': '0.4s',
                'from': 'left',
                'overlap': true,
                'ease': 'linear',
              },
            },
          ),
        ),
        containsCode('Transition.slide(0.4.seconds, from: Edge.left'),
      );
      expect(
        printVideoSpecJson(
          _wrap(
            [
              {'type': 'Text', 'text': 'x'},
            ],
            scene: {
              'enter': {'kind': 'cut'},
            },
          ),
        ),
        containsCode('enter: Transition.cut()'),
      );
    });
  });

  group('exports and alignment objects', () {
    Map<String, Object?> withExport(Map<String, Object?> export) => {
      ..._wrap([
        {'type': 'Text', 'text': 'x'},
      ]),
      'export': export,
    };

    test('gif, imageSequence and transparent exports', () {
      expect(
        printVideoSpecJson(withExport({'mode': 'gif', 'fps': 15})),
        containsCode('Export.gif(fps: 15)'),
      );
      expect(
        printVideoSpecJson(withExport({'mode': 'imageSequence', 'format': 'png'})),
        containsCode('Export.imageSequence(format: ImageFormat.png)'),
      );
      expect(
        printVideoSpecJson(withExport({'mode': 'transparent'})),
        containsCode('Export.transparent()'),
      );
    });

    test('explicit {x, y} alignment in a gradient', () {
      expect(
        printVideoSpecJson(
          _wrap(
            [
              {'type': 'Text', 'text': 'x'},
            ],
            scene: {
              'background': {
                'kind': 'gradient',
                'colors': ['#FF000000', '#FFFFFFFF'],
                'begin': {'x': 0.3, 'y': -0.5},
              },
            },
          ),
        ),
        containsCode('begin: Alignment(0.3, -0.5)'),
      );
    });
  });

  group('font weights', () {
    test('bold and normal weights', () {
      expect(
        printVideoSpecJson(
          _wrap([
            {
              'type': 'Text',
              'text': 'x',
              'style': {'fontWeight': 'bold'},
            },
          ]),
        ),
        containsCode('fontWeight: FontWeight.bold'),
      );
      expect(
        printVideoSpecJson(
          _wrap([
            {
              'type': 'Text',
              'text': 'x',
              'style': {'fontWeight': 'normal'},
            },
          ]),
        ),
        containsCode('fontWeight: FontWeight.normal'),
      );
    });
  });

  group('anchor naming', () {
    String declFor(String id) => printVideoSpecJson(
      _wrap([
        {'type': 'Text', 'text': 'x', 'anchor': id},
      ]),
    );

    test('multi-word, leading-digit, symbol-only and reserved ids', () {
      expect(declFor('main title'), containsCode("final mainTitle = Anchor('main title');"));
      expect(declFor('1st'), containsCode("final a1st = Anchor('1st');"));
      expect(declFor('###'), containsCode("final anchor = Anchor('###');"));
      expect(declFor('class'), containsCode("final class1 = Anchor('class');"));
    });

    test('ids that sanitize alike get distinct, numbered variables', () {
      final code = printVideoSpecJson(
        _wrap([
          {'type': 'Text', 'text': 'a', 'anchor': 'intro'},
          {'type': 'Text', 'text': 'b', 'anchor': 'intro!'},
          {'type': 'Text', 'text': 'c', 'anchor': 'intro?'},
        ]),
      );
      expect(code, containsCode("final intro = Anchor('intro');"));
      expect(code, containsCode("final intro1 = Anchor('intro!');"));
      expect(code, containsCode("final intro2 = Anchor('intro?');"));
    });
  });

  group('string escaping (remaining control characters)', () {
    test('tab, carriage return, null and unicode separators', () {
      // Built from code units so the source stays clean ASCII: tab, CR, NUL,
      // line separator, paragraph separator, and DEL.
      final text = String.fromCharCodes([
        0x61,
        0x09,
        0x0D,
        0x08,
        0x0C,
        0x0B,
        0x00,
        0x2028,
        0x2029,
        0x7F,
        0x62,
      ]);
      final code = printVideoSpecJson(
        _wrap([
          {'type': 'Text', 'text': text},
        ]),
      );
      expect(code, contains(r'\t'));
      expect(code, contains(r'\r'));
      expect(code, contains(r'\b'));
      expect(code, contains(r'\f'));
      expect(code, contains(r'\v'));
      expect(code, contains(r'\u{0}'));
      expect(code, contains(r'\u{2028}'));
      expect(code, contains(r'\u{2029}'));
      expect(code, contains(r'\u{7f}'));
    });
  });

  group('defensive guards', () {
    test('non-finite numbers are rejected', () {
      expect(
        () => printVideoSpecJson(
          _wrap([
            {'type': 'Counter', 'to': double.infinity},
          ]),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('unknown variants throw', () {
      expect(
        () => printVideoSpecJson(
          _wrap([
            {'type': 'Bogus'},
          ]),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => printVideoSpecJson(
          _wrap([
            {
              'type': 'Text',
              'text': 'x',
              'animate': [
                {'preset': 'nope'},
              ],
            },
          ]),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => printVideoSpecJson(
          _wrap(
            [
              {'type': 'Text', 'text': 'x'},
            ],
            scene: {
              'background': {'kind': 'nope'},
            },
          ),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => printVideoSpecJson(
          _wrap([
            {
              'type': 'Text',
              'text': 'x',
              'animate': [
                {'preset': 'fadeIn', 'at': 'nope'},
              ],
            },
          ]),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => printVideoSpecJson(
          _wrap([
            {
              'type': 'Image',
              'source': {'kind': 'nope', 'value': 'x'},
            },
          ]),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => printVideoSpecJson(
          _wrap([
            {
              'type': 'Text',
              'text': 'x',
              'animate': [
                {
                  'preset': 'fadeIn',
                  'at': {'kind': 'nope'},
                },
              ],
            },
          ]),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => printVideoSpecJson(
          _wrap(
            [
              {'type': 'Text', 'text': 'x'},
            ],
            scene: {
              'enter': {'kind': 'nope', 'duration': '1.0s'},
            },
          ),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => printVideoSpecJson({
          ..._wrap([
            {'type': 'Text', 'text': 'x'},
          ]),
          'export': {'mode': 'nope'},
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('a spec without a scenes list yields an empty scenes literal', () {
      final code = printVideoSpecJson({'fluvieSpec': 1, 'size': 'square', 'fps': 30});
      expect(code, containsCode('scenes: []'));
    });
  });

  group('literal edge cases', () {
    test('a six-digit color gains an opaque alpha', () {
      expect(
        printVideoSpecJson(
          _wrap(
            [
              {'type': 'Text', 'text': 'x'},
            ],
            scene: {
              'background': {'kind': 'color', 'color': '#112233'},
            },
          ),
        ),
        containsCode('Background.color(Color(0xFF112233))'),
      );
    });

    test('an unrecognized or malformed time string throws', () {
      Map<String, Object?> withDuration(String duration) => {
        'fluvieSpec': 1,
        'size': 'square',
        'fps': 30,
        'scenes': [
          {
            'duration': duration,
            'children': [
              {'type': 'Text', 'text': 'x'},
            ],
          },
        ],
      };
      expect(() => printVideoSpecJson(withDuration('nope')), throwsA(isA<FormatException>()));
      expect(() => printVideoSpecJson(withDuration('0.2rX')), throwsA(isA<FormatException>()));
    });

    test('a non-numeric where a number is expected throws', () {
      expect(
        () => printVideoSpecJson(
          _wrap([
            {'type': 'Counter', 'to': 'oops'},
          ]),
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
