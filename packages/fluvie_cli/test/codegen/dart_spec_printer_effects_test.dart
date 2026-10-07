// An effect stack in the printed Dart. Effects render, so they print as a
// real `.effects([...])` call in the slot the spec builds them — inside the
// animate wrapper and outside the element.

import 'package:fluvie_cli/src/codegen/dart_spec_printer.dart';
import 'package:test/test.dart';

/// Strips whitespace and `dart_style`'s wrap-only trailing commas so a code
/// fragment matches regardless of how the formatter line-wraps it.
String _canon(String code) => code
    .replaceAll(RegExp(r'\s+'), '')
    .replaceAll(',)', ')')
    .replaceAll(',]', ']')
    .replaceAll(',}', '}');

/// Matches when [fragment] appears in the code ignoring formatting (line
/// wraps, indentation, and trailing commas).
Matcher containsCode(String fragment) => predicate<String>(
  (code) => _canon(code).contains(_canon(fragment)),
  'contains code `$fragment` (ignoring formatting)',
);

Map<String, Object?> _spec({List<Object?>? effects, List<Object?>? animate}) => {
  'fluvieSpec': 1,
  'scenes': [
    {
      'duration': '8s',
      'children': [
        {
          'id': 'el-title',
          'type': 'Text',
          'text': 'Graded',
          'effects': ?effects,
          'animate': ?animate,
        },
      ],
    },
  ],
};

void main() {
  test('blur, glitch intensity, and embedded LUT print as usable effect factories', () {
    final code = printVideoSpecJson(
      _spec(
        effects: [
          {'kind': 'blur', 'sigma': 12},
          {'kind': 'glitch', 'intensity': 0.4},
          {'kind': 'lut', 'cube': 'LUT_3D_SIZE 2\n', 'intensity': 0.6},
        ],
      ),
    );
    expect(code, containsCode('Effect.blur(sigma: 12)'));
    expect(code, containsCode('Effect.glitch(intensity: 0.4)'));
    expect(code, contains('cube:'));
    expect(code, contains('LUT_3D_SIZE 2'));
  });

  test('an element without effects prints no effects call', () {
    expect(printVideoSpecJson(_spec()), isNot(contains('.effects(')));
  });

  test('an effect prints as a named Effect literal', () {
    final code = printVideoSpecJson(
      _spec(
        effects: [
          {'kind': 'grain', 'amount': 0.35},
        ],
      ),
    );

    expect(code, contains('.effects([Effect.grain(amount: 0.35)])'));
  });

  test('the stack keeps the order it was written in', () {
    // The class ordering is the stack's job at build time; the printer's job
    // is to hand back exactly what the document said.
    final code = printVideoSpecJson(
      _spec(
        effects: [
          {'kind': 'grain'},
          {'kind': 'vignette'},
        ],
      ),
    );

    expect(code.indexOf('Effect.grain'), lessThan(code.indexOf('Effect.vignette')));
  });

  test('a disabled effect prints through the spec spelling, still off', () {
    // The named factories have no enabled flag on purpose; a document that
    // carries one prints the spelling that does.
    final code = printVideoSpecJson(
      _spec(
        effects: [
          {'kind': 'grain', 'enabled': false, 'amount': 0.2},
        ],
      ),
    );

    expect(
      code,
      containsCode(
        'Effect.spec(EffectSpec(EffectSpecKind.grain, enabled: false, '
        "params: {'amount': 0.2}))",
      ),
    );
  });

  test('a keyframed parameter prints as a KeyframedNumber through the spec spelling', () {
    final code = printVideoSpecJson(
      _spec(
        effects: [
          {
            'kind': 'vignette',
            'amount': {
              'values': [0, 0.9],
              'positions': ['0f', '90f'],
            },
          },
        ],
      ),
    );

    expect(
      code,
      containsCode(
        'Effect.spec(EffectSpec(EffectSpecKind.vignette, params: '
        "{'amount': KeyframedNumber.linear(values: [0, 0.9], "
        'positions: [0.frames, 90.frames])}))',
      ),
    );
  });

  test('a keyframed parameter with easings prints the full form', () {
    final code = printVideoSpecJson(
      _spec(
        effects: [
          {
            'kind': 'vignette',
            'amount': {
              'values': [0, 1, 0],
              'positions': ['0f', '45f', '90f'],
              'easings': ['smooth', 'in'],
            },
          },
        ],
      ),
    );

    expect(
      code,
      containsCode(
        "'amount': KeyframedNumber(values: [0, 1, 0], "
        'positions: [0.frames, 45.frames, 90.frames], '
        'easings: [Ease.smooth, Ease.in_])',
      ),
    );
  });

  test('a shader uniform named "values" stays a uniforms map', () {
    // "values" names a float slot on this shader; the printer must not
    // mistake the author's uniforms object for a keyframed parameter.
    final code = printVideoSpecJson(
      _spec(
        effects: [
          {
            'kind': 'shader',
            'asset': 'shaders/warp.frag',
            'uniforms': {
              'values': [1.0, 2.0],
              'positions': [0.25],
            },
          },
        ],
      ),
    );

    expect(code, isNot(contains('KeyframedNumber')));
    expect(
      code,
      containsCode("uniforms: {'values': [1.0, 2.0], 'positions': [0.25]}"),
    );
  });

  test('a curves effect prints through the spec spelling', () {
    // Its channel lists have no literal spelling through the typed facade,
    // so the document form keeps the spec spelling, like particles.
    final code = printVideoSpecJson(
      _spec(
        effects: [
          {
            'kind': 'curves',
            'curves': {
              'master': [
                [0, 0],
                [1, 1],
              ],
            },
          },
        ],
      ),
    );

    expect(
      code,
      containsCode(
        'Effect.spec(EffectSpec(EffectSpecKind.curves, params: '
        "{'curves': {'master': [[0, 0], [1, 1]]}}))",
      ),
    );
  });

  test('a lut effect prints through the named factory', () {
    final code = printVideoSpecJson(
      _spec(
        effects: [
          {'kind': 'lut', 'asset': 'luts/warm.cube', 'intensity': 0.6},
        ],
      ),
    );

    expect(code, containsCode("Effect.lut(asset: 'luts/warm.cube', intensity: 0.6)"));
  });

  test('a particles effect prints through the spec spelling', () {
    // Its facade parameter is a typed Particles, so the document form keeps
    // the spec spelling rather than pretending the map is one.
    final code = printVideoSpecJson(
      _spec(
        effects: [
          {
            'kind': 'particles',
            'particles': {'kind': 'confetti', 'count': 40, 'seed': 'launch'},
          },
        ],
      ),
    );

    expect(
      code,
      containsCode(
        'Effect.spec(EffectSpec(EffectSpecKind.particles, params: '
        "{'particles': {'kind': 'confetti', 'count': 40, 'seed': 'launch'}}))",
      ),
    );
  });

  test('a string parameter prints quoted', () {
    final code = printVideoSpecJson(
      _spec(
        effects: [
          {'kind': 'shader', 'asset': 'shaders/glow.frag'},
        ],
      ),
    );

    expect(code, contains("asset: 'shaders/glow.frag'"));
  });

  test('the stack sits inside the animate wrapper, exactly as it builds', () {
    final code = printVideoSpecJson(
      _spec(
        effects: [
          {'kind': 'grain'},
        ],
        animate: [
          {'preset': 'fadeIn', 'duration': '12f'},
        ],
      ),
    );

    expect(code.indexOf('.effects('), lessThan(code.indexOf('.animate(')));
  });
}
