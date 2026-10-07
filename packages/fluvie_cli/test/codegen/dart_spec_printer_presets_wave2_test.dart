import 'package:fluvie_cli/src/codegen/dart_spec_printer.dart';
import 'package:test/test.dart';

Map<String, Object?> _animated(Map<String, Object?> animation) => {
  'fluvieSpec': 1,
  'size': 'hd',
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'children': [
        {
          'type': 'Box',
          'color': '#6C5CE7',
          'animate': [animation],
        },
      ],
    },
  ],
};

void main() {
  group('wave-2 presets print their calls', () {
    test('color and gradientShift', () {
      expect(
        printVideoSpecJson(_animated({'preset': 'color', 'to': '#FFD166', 'duration': '20f'})),
        allOf(
          contains('Animation.color('),
          contains('to: Color(0xFFFFD166)'),
          contains('duration: 20.frames'),
        ),
      );
      expect(
        printVideoSpecJson(
          _animated({
            'preset': 'gradientShift',
            'to': ['#101018', '#3C1E5A'],
          }),
        ),
        allOf(
          contains('Animation.gradientShift('),
          contains('to: [Color(0xFF101018), Color(0xFF3C1E5A)]'),
        ),
      );
    });

    test('the pixel post-effects', () {
      expect(
        printVideoSpecJson(_animated({'preset': 'scanlines'})),
        contains('Animation.scanlines()'),
      );
      expect(
        printVideoSpecJson(_animated({'preset': 'chromatic', 'px': 2})),
        contains('Animation.chromatic(2)'),
      );
      expect(
        printVideoSpecJson(_animated({'preset': 'chromatic'})),
        contains('Animation.chromatic(0)'),
      );
      expect(
        printVideoSpecJson(_animated({'preset': 'bloom', 'amount': 0.4})),
        contains('Animation.bloom(0.4)'),
      );
      expect(
        printVideoSpecJson(_animated({'preset': 'parallax', 'depth': 0.35})),
        contains('Animation.parallax(depth: 0.35)'),
      );
      expect(
        printVideoSpecJson(_animated({'preset': 'parallax'})),
        contains('Animation.parallax()'),
      );
    });

    test('particles print their kind with only the overridden fields', () {
      expect(
        printVideoSpecJson(
          _animated({
            'preset': 'particles',
            'spec': {'kind': 'confetti', 'count': 40, 'seed': 'launch'},
          }),
        ),
        allOf(
          contains('Animation.particles('),
          contains('Particles.confetti('),
          contains('count: 40'),
          contains("seed: 'launch'"),
        ),
      );
      expect(
        printVideoSpecJson(
          _animated({
            'preset': 'particles',
            'spec': {
              'kind': 'snow',
              'palette': ['#FFFFFF', '#E0E0FF'],
              'minSize': 2,
              'maxSize': 5,
              'fallSpeed': 0.3,
              'drift': 0.1,
              'spinSpeed': 0.2,
            },
          }),
        ),
        allOf(
          contains('Particles.snow('),
          contains('palette: [Color(0xFFFFFFFF), Color(0xFFE0E0FF)]'),
          contains('minSize: 2'),
          contains('maxSize: 5'),
          contains('fallSpeed: 0.3'),
          contains('drift: 0.1'),
          contains('spinSpeed: 0.2'),
        ),
      );
      expect(
        printVideoSpecJson(
          _animated({
            'preset': 'particles',
            'spec': {'kind': 'sparkle'},
          }),
        ),
        contains('Particles.sparkle()'),
      );
      expect(
        () => printVideoSpecJson(
          _animated({
            'preset': 'particles',
            'spec': {'kind': 'plasma'},
          }),
        ),
        throwsFormatException,
      );
    });

    test('shader prints its asset and uniforms map', () {
      expect(
        printVideoSpecJson(
          _animated({
            'preset': 'shader',
            'asset': 'shaders/ripple.frag',
            'uniforms': {'speed': 2},
          }),
        ),
        allOf(
          contains("Animation.shader('shaders/ripple.frag'"),
          contains("uniforms: {'speed': 2}"),
        ),
      );
      expect(
        printVideoSpecJson(_animated({'preset': 'shader', 'asset': 'a.frag'})),
        contains("Animation.shader('a.frag')"),
      );
      expect(
        printVideoSpecJson(
          _animated({'preset': 'shader', 'asset': 'a.frag', 'uniforms': <String, Object?>{}}),
        ),
        contains("Animation.shader('a.frag')"),
      );
    });

    test('scaleY and the reactive pulse share the track anchor variable', () {
      final code = printVideoSpecJson({
        'fluvieSpec': 1,
        'size': 'hd',
        'fps': 30,
        'scenes': [
          {
            'duration': '60f',
            'children': [
              {
                'type': 'Box',
                'color': '#6C5CE7',
                'animate': [
                  {'preset': 'scaleY', 'on': 'mid', 'gain': 1.5, 'track': 'music'},
                  {'preset': 'pulse', 'on': 'bass', 'gain': 1.4, 'track': 'music'},
                ],
              },
            ],
          },
        ],
      });
      expect(code, contains("final music = Anchor('music');"));
      expect(code, contains('Animation.scaleY('));
      expect(code, contains('on: AudioBand.mid'));
      expect(code, contains('gain: 1.5'));
      expect(code, contains('on: AudioBand.bass'));
      expect(code, contains('gain: 1.4'));
      expect('track: music'.allMatches(code), hasLength(2));
    });

    test('the sine pulse still prints without reactive arguments', () {
      expect(
        printVideoSpecJson(_animated({'preset': 'pulse', 'min': 0.9, 'max': 1.1})),
        allOf(contains('min: 0.9'), contains('max: 1.1'), isNot(contains('AudioBand'))),
      );
    });

    test('along prints pathFromSvg with orient and phase', () {
      expect(
        printVideoSpecJson(
          _animated({'preset': 'along', 'path': 'M 0 0 L 100 50', 'orient': false}),
        ),
        allOf(contains("Animation.along(pathFromSvg('M 0 0 L 100 50')"), contains('orient: false')),
      );
      expect(
        printVideoSpecJson(
          _animated({'preset': 'along', 'path': 'M 0 0 L 1 1', 'phase': 'during'}),
        ),
        allOf(
          contains("pathFromSvg('M 0 0 L 1 1')"),
          contains('phase: AnimationPhase.during'),
          isNot(contains('orient:')),
        ),
      );
    });
  });
}
