import 'package:fluvie_cli/src/codegen/dart_spec_printer.dart';
import 'package:test/test.dart';

Map<String, Object?> _doc({List<Object?>? videoAudio, List<Object?>? sceneAudio}) => {
  'fluvieSpec': 1,
  'size': 'hd',
  'fps': 30,
  'audio': ?videoAudio,
  'scenes': [
    {
      'duration': '60f',
      'audio': ?sceneAudio,
      'children': [
        {'type': 'Text', 'text': 'hi'},
      ],
    },
  ],
};

void main() {
  group('audio tracks print their constructors', () {
    test('a bundle audio source prints its bundle path as the source string', () {
      // Bare of a leading slash or scheme, the engine classifies the printed
      // value as an asset key; ship the bundle's media folder as assets.
      final code = printVideoSpecJson(
        _doc(
          videoAudio: [
            {
              'kind': 'music',
              'source': {'kind': 'bundle', 'value': 'media/bed.mp3'},
            },
          ],
        ),
      );
      expect(code, contains("Audio.music('media/bed.mp3')"));
    });

    test('a full music track prints Audio.music with every field', () {
      final code = printVideoSpecJson(
        _doc(
          videoAudio: [
            {
              'kind': 'music',
              'source': {'kind': 'file', 'value': '/home/ada/music/bed.mp3'},
              'volume': 0.8,
              'fadeIn': '30f',
              'fadeOut': '60f',
              'loop': true,
              'trim': {'from': '0f', 'to': '900f'},
              'track': 'bed',
            },
          ],
        ),
      );
      expect(
        code,
        allOf([
          contains('Audio.music('),
          contains("'/home/ada/music/bed.mp3'"),
          contains('volume: 0.8'),
          contains('fadeIn: 30.frames'),
          contains('fadeOut: 60.frames'),
          contains('loop: true'),
          contains('trim: TimeRange(0.frames, 900.frames)'),
          contains('track: bed'),
          contains("final bed = Anchor('bed');"),
          contains('audio: ['),
        ]),
      );
    });

    test('a bare music track elides every default', () {
      final code = printVideoSpecJson(
        _doc(
          videoAudio: [
            {
              'kind': 'music',
              'source': {'kind': 'asset', 'value': 'audio/bed.mp3'},
            },
          ],
        ),
      );
      expect(
        code,
        allOf(
          contains("Audio.music('audio/bed.mp3')"),
          isNot(contains('volume:')),
          isNot(contains('loop:')),
          isNot(contains('Anchor(')),
        ),
      );
    });

    test('a scene sfx prints Audio.sfx inside the Scene', () {
      final code = printVideoSpecJson(
        _doc(
          sceneAudio: [
            {
              'kind': 'sfx',
              'source': {'kind': 'asset', 'value': 'audio/whoosh.mp3'},
              'at': {'kind': 'at', 'time': '500ms'},
              'volume': 0.6,
            },
          ],
        ),
      );
      expect(
        code,
        allOf(
          contains("Audio.sfx('audio/whoosh.mp3'"),
          contains('at: Trigger.at(500.ms)'),
          contains('volume: 0.6'),
        ),
      );
      expect(code.indexOf('Scene('), lessThan(code.indexOf('Audio.sfx')));
    });

    test('a music track id shares its anchor variable with a beat trigger', () {
      final code = printVideoSpecJson({
        'fluvieSpec': 1,
        'size': 'hd',
        'fps': 30,
        'audio': [
          {
            'kind': 'music',
            'source': {'kind': 'asset', 'value': 'audio/bed.mp3'},
            'track': 'bed',
          },
        ],
        'scenes': [
          {
            'duration': '60f',
            'children': [
              {
                'type': 'Text',
                'text': 'Drop',
                'animate': [
                  {
                    'preset': 'pop',
                    'duration': '12f',
                    'at': {'kind': 'beat', 'every': 2, 'track': 'bed'},
                  },
                ],
              },
            ],
          },
        ],
      });
      expect(code, contains("final bed = Anchor('bed');"));
      expect(code, contains("Audio.music('audio/bed.mp3', track: bed)"));
      expect(code, contains('Trigger.beat(every: 2, track: bed)'));
      expect("final bed = Anchor('bed');".allMatches(code), hasLength(1));
    });

    test('an unknown track kind fails loudly', () {
      expect(
        () => printVideoSpecJson(
          _doc(
            videoAudio: [
              {
                'kind': 'voice',
                'source': {'kind': 'asset', 'value': 'a.mp3'},
              },
            ],
          ),
        ),
        throwsFormatException,
      );
    });
  });
}
