import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/runtime/audio_collector.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/serialization/scene_spec.dart';
import 'package:fluvie/src/serialization/spec_validation.dart';
import 'package:fluvie/src/serialization/video_spec.dart';
import 'package:fluvie/src/serialization/video_spec_schema.dart';

/// The ADR-shaped document: a video-level music bed (loop, fades, trim, and a
/// beat-grid anchor a beat trigger pairs with) plus a scene-level sfx at an
/// offset.
Map<String, Object?> _document() => {
  'fluvieSpec': 1,
  'size': {'width': 640, 'height': 360},
  'fps': 30,
  'audio': [
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
  'scenes': [
    {
      'duration': '120f',
      'audio': [
        {
          'kind': 'sfx',
          'source': {'kind': 'asset', 'value': 'audio/whoosh.mp3'},
          'at': {'kind': 'at', 'time': '500ms'},
          'volume': 0.6,
        },
      ],
      'children': [
        {
          'id': 'el-title',
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
};

Map<String, Object?> _minimal({List<Object?>? videoAudio, List<Object?>? sceneAudio}) => {
  'fluvieSpec': 1,
  'size': 'hd',
  'fps': 30,
  'audio': ?videoAudio,
  'scenes': [
    {
      'duration': '2s',
      'audio': ?sceneAudio,
      'children': [
        {'id': 'el-a', 'type': 'Text', 'text': 'hi'},
      ],
    },
  ],
};

Matcher _specError(String path) =>
    throwsA(isA<FluvieSpecError>().having((error) => error.path.join('.'), 'path', path));

void main() {
  group('the audio track codec', () {
    test('round-trips the ADR document canonically', () {
      final spec = VideoSpec.fromJson(_document());
      expect(spec.toJson(), _document());
    });

    test('elides every default', () {
      final spec = VideoSpec.fromJson(
        _minimal(
          videoAudio: [
            {
              'kind': 'music',
              'source': {'kind': 'asset', 'value': 'audio/bed.mp3'},
              'volume': 1,
              'loop': false,
            },
            {
              'kind': 'sfx',
              'source': {'kind': 'asset', 'value': 'audio/tick.mp3'},
              'volume': 1,
            },
          ],
        ),
      );
      expect(spec.toJson()['audio'], [
        {
          'kind': 'music',
          'source': {'kind': 'asset', 'value': 'audio/bed.mp3'},
        },
        {
          'kind': 'sfx',
          'source': {'kind': 'asset', 'value': 'audio/tick.mp3'},
        },
      ]);
    });

    test('absent audio parses to empty lists and stays absent on encode', () {
      final spec = VideoSpec.fromJson(_minimal());
      expect(spec.audio, isEmpty);
      expect(spec.scenes.single.audio, isEmpty);
      expect(spec.toJson(), isNot(contains('audio')));
      expect(spec.toJson()['scenes'], [isNot(contains('audio'))]);
    });

    test('knownKeys name audio at both levels', () {
      expect(VideoSpec.knownKeys, contains('audio'));
      expect(SceneSpec.knownKeys, contains('audio'));
    });
  });

  group('building spec audio', () {
    test('spec audio reaches collectAudioTracks with every field intact', () {
      final video = VideoSpec.fromJson(_document()).build();
      final tracks = collectAudioTracks(video);
      expect(tracks, hasLength(2));
      final music = tracks[0];
      expect(music.isSfx, isFalse);
      expect(music.source, '/home/ada/music/bed.mp3');
      expect(music.volume, closeTo(0.8, 1e-9));
      expect(music.fadeIn, const Time.frames(30));
      expect(music.fadeOut, const Time.frames(60));
      expect(music.loop, isTrue);
      expect(music.trim!.start, Time.zero);
      expect(music.trim!.end, const Time.frames(900));
      expect(music.audioSource, isA<FileAudioSource>());
      final sfx = tracks[1];
      expect(sfx.isSfx, isTrue);
      expect(sfx.source, 'audio/whoosh.mp3');
      expect(sfx.volume, closeTo(0.6, 1e-9));
      expect(sfx.at, const Trigger.at(Time.ms(500)));
      expect(sfx.audioSource, isA<AssetAudioSource>());
    });

    test('a network source builds a network track', () {
      final spec = VideoSpec.fromJson(
        _minimal(
          videoAudio: [
            {
              'kind': 'music',
              'source': {'kind': 'network', 'value': 'https://cdn.example/bed.mp3'},
            },
          ],
        ),
      );
      final track = collectAudioTracks(spec.build()).single;
      expect(track.audioSource, isA<NetworkAudioSource>());
      expect(track.source, 'https://cdn.example/bed.mp3');
    });

    test("the music track anchor is the document's anchor instance", () {
      final spec = VideoSpec.fromJson(_document());
      final music = collectAudioTracks(spec.build()).first;
      expect(music.track?.debugName, 'bed');
      expect(identical(music.track, spec.anchors.resolve('bed')), isTrue);
    });

    test('a scene adopting a master keeps its audio', () {
      final spec = VideoSpec.fromJson({
        'fluvieSpec': 1,
        'size': 'hd',
        'fps': 30,
        'masters': {
          'plain': {
            'children': [
              {
                'type': 'Box',
                'transform': {'x': 0.5, 'y': 0.5, 'w': 1.0, 'h': 0.1},
              },
            ],
          },
        },
        'scenes': [
          {
            'duration': '2s',
            'master': 'plain',
            'audio': [
              {
                'kind': 'sfx',
                'source': {'kind': 'asset', 'value': 'audio/whoosh.mp3'},
              },
            ],
          },
        ],
      });
      final track = collectAudioTracks(spec.build()).single;
      expect(track.source, 'audio/whoosh.mp3');
      expect(track.isSfx, isTrue);
    });
  });

  group('the digest counts audio', () {
    test('adding a track moves the digest', () {
      final silent = VideoSpec.fromJson(_minimal());
      final scored = VideoSpec.fromJson(
        _minimal(
          videoAudio: [
            {
              'kind': 'music',
              'source': {'kind': 'asset', 'value': 'audio/bed.mp3'},
            },
          ],
        ),
      );
      expect(scored.digest(), isNot(silent.digest()));
    });

    test('changing a track field moves the digest', () {
      Map<String, Object?> at(double volume) => _minimal(
        sceneAudio: [
          {
            'kind': 'sfx',
            'source': {'kind': 'asset', 'value': 'audio/tick.mp3'},
            'volume': volume,
          },
        ],
      );
      expect(
        VideoSpec.fromJson(at(0.5)).digest(),
        isNot(VideoSpec.fromJson(at(0.8)).digest()),
      );
    });
  });

  group('parse errors', () {
    Map<String, Object?> videoTrack(Map<String, Object?> track) => _minimal(videoAudio: [track]);

    test('audio must be a list', () {
      expect(
        () => VideoSpec.fromJson(_minimal()..['audio'] = <String, Object?>{}),
        _specError('audio'),
      );
    });

    test('a track must be an object', () {
      expect(() => VideoSpec.fromJson(_minimal(videoAudio: ['boom'])), _specError('audio.0'));
    });

    test('an unknown kind is rejected', () {
      expect(
        () => VideoSpec.fromJson(
          videoTrack({
            'kind': 'voice',
            'source': {'kind': 'asset', 'value': 'a.mp3'},
          }),
        ),
        _specError('audio.0.kind'),
      );
    });

    test('a track needs a source object', () {
      expect(
        () => VideoSpec.fromJson(videoTrack({'kind': 'music'})),
        _specError('audio.0.source'),
      );
    });

    test('an unknown source kind is rejected', () {
      expect(
        () => VideoSpec.fromJson(
          videoTrack({
            'kind': 'music',
            'source': {'kind': 'memory', 'value': 'a.mp3'},
          }),
        ),
        _specError('audio.0.source.kind'),
      );
    });

    test('a source needs a non-empty string value', () {
      expect(
        () => VideoSpec.fromJson(
          videoTrack({
            'kind': 'music',
            'source': {'kind': 'asset'},
          }),
        ),
        _specError('audio.0.source.value'),
      );
      expect(
        () => VideoSpec.fromJson(
          videoTrack({
            'kind': 'music',
            'source': {'kind': 'asset', 'value': ''},
          }),
        ),
        _specError('audio.0.source.value'),
      );
    });

    test('a file source needs an absolute path', () {
      expect(
        () => VideoSpec.fromJson(
          videoTrack({
            'kind': 'music',
            'source': {'kind': 'file', 'value': 'relative/bed.mp3'},
          }),
        ),
        _specError('audio.0.source.value'),
      );
    });

    test('a network source needs an http url with a host', () {
      expect(
        () => VideoSpec.fromJson(
          videoTrack({
            'kind': 'music',
            'source': {'kind': 'network', 'value': 'not a url'},
          }),
        ),
        _specError('audio.0.source.value'),
      );
    });

    test('an asset source is a bundle key, not a path or url', () {
      expect(
        () => VideoSpec.fromJson(
          videoTrack({
            'kind': 'music',
            'source': {'kind': 'asset', 'value': '/abs/bed.mp3'},
          }),
        ),
        _specError('audio.0.source.value'),
      );
      expect(
        () => VideoSpec.fromJson(
          videoTrack({
            'kind': 'music',
            'source': {'kind': 'asset', 'value': 'https://cdn.example/bed.mp3'},
          }),
        ),
        _specError('audio.0.source.value'),
      );
    });

    test('a negative or non-numeric volume is rejected', () {
      expect(
        () => VideoSpec.fromJson(
          videoTrack({
            'kind': 'sfx',
            'source': {'kind': 'asset', 'value': 'a.mp3'},
            'volume': -0.2,
          }),
        ),
        _specError('audio.0.volume'),
      );
      expect(
        () => VideoSpec.fromJson(
          videoTrack({
            'kind': 'sfx',
            'source': {'kind': 'asset', 'value': 'a.mp3'},
            'volume': 'loud',
          }),
        ),
        _specError('audio.0.volume'),
      );
    });

    test('a malformed music placement is rejected', () {
      expect(
        () => VideoSpec.fromJson(
          videoTrack({
            'kind': 'music',
            'source': {'kind': 'asset', 'value': 'a.mp3'},
            'at': {'kind': 'not-a-trigger'},
          }),
        ),
        _specError('audio.0.at'),
      );
    });

    test('every music-only key on an sfx track is rejected', () {
      const musicOnly = <String, Object?>{
        'fadeIn': '1s',
        'fadeOut': '1s',
        'loop': true,
        'trim': {'from': '0s', 'to': '1s'},
        'track': 'bed',
      };
      for (final entry in musicOnly.entries) {
        expect(
          () => VideoSpec.fromJson(
            videoTrack({
              'kind': 'sfx',
              'source': {'kind': 'asset', 'value': 'a.mp3'},
              entry.key: entry.value,
            }),
          ),
          _specError('audio.0.${entry.key}'),
          reason: entry.key,
        );
      }
    });

    test('a music loop must be a boolean', () {
      expect(
        () => VideoSpec.fromJson(
          videoTrack({
            'kind': 'music',
            'source': {'kind': 'asset', 'value': 'a.mp3'},
            'loop': 'yes',
          }),
        ),
        _specError('audio.0.loop'),
      );
    });

    test('a music track name must be a string', () {
      expect(
        () => VideoSpec.fromJson(
          videoTrack({
            'kind': 'music',
            'source': {'kind': 'asset', 'value': 'a.mp3'},
            'track': 3,
          }),
        ),
        _specError('audio.0.track'),
      );
    });

    test('trim must be a {from, to} object of times', () {
      expect(
        () => VideoSpec.fromJson(
          videoTrack({
            'kind': 'music',
            'source': {'kind': 'asset', 'value': 'a.mp3'},
            'trim': '1s',
          }),
        ),
        _specError('audio.0.trim'),
      );
      expect(
        () => VideoSpec.fromJson(
          videoTrack({
            'kind': 'music',
            'source': {'kind': 'asset', 'value': 'a.mp3'},
            'trim': {'from': '0s'},
          }),
        ),
        _specError('audio.0.trim.to'),
      );
    });

    test('scene-level errors carry the scene path', () {
      expect(
        () => VideoSpec.fromJson(
          _minimal(
            sceneAudio: [
              {
                'kind': 'sfx',
                'source': {'kind': 'asset', 'value': 'a.mp3'},
                'loop': true,
              },
            ],
          ),
        ),
        _specError('scenes.0.audio.0.loop'),
      );
    });
  });

  group('the pure validator', () {
    test('the ADR document validates clean', () {
      expect(unknownSpecProps(_document()), isEmpty);
    });

    test('an unknown key on a music track warns with its path', () {
      final warnings = unknownSpecProps(
        _minimal(
          videoAudio: [
            {
              'kind': 'music',
              'source': {'kind': 'asset', 'value': 'a.mp3'},
              'foo': 1,
            },
          ],
        ),
      );
      expect(warnings, hasLength(1));
      expect(warnings.single.path, ['audio', '0']);
      expect(warnings.single.message, contains('"foo"'));
    });

    test('a music-only key on an sfx track warns at the scene path', () {
      final warnings = unknownSpecProps(
        _minimal(
          sceneAudio: [
            {
              'kind': 'sfx',
              'source': {'kind': 'asset', 'value': 'a.mp3'},
              'fadeIn': '1s',
            },
          ],
        ),
      );
      expect(warnings, hasLength(1));
      expect(warnings.single.path, ['scenes', '0', 'audio', '0']);
      expect(warnings.single.message, contains('"fadeIn"'));
    });

    test('nested source and trim shapes are closed', () {
      final warnings = unknownSpecProps(
        _minimal(
          videoAudio: [
            {
              'kind': 'music',
              'source': {'kind': 'asset', 'value': 'a.mp3', 'mime': 'audio/mpeg'},
              'trim': {'from': '0s', 'to': '1s', 'speed': 2},
            },
          ],
        ),
      );
      expect(warnings, hasLength(2));
      expect(warnings[0].path, ['audio', '0', 'source']);
      expect(warnings[1].path, ['audio', '0', 'trim']);
    });

    test('an unknown kind and a non-object entry are left for the parser', () {
      final warnings = unknownSpecProps(
        _minimal(
          videoAudio: [
            'boom',
            {'kind': 'voice', 'anything': true},
          ],
        ),
      );
      expect(warnings, isEmpty);
    });
  });

  group('the schema advertises audio', () {
    Map<String, Object?> defs() => videoSpecSchema[r'$defs']! as Map<String, Object?>;

    test('an audioTrack def exists with closed music and sfx variants', () {
      final track = defs()['audioTrack']! as Map<String, Object?>;
      final variants = track['oneOf']! as List<Object?>;
      expect(variants, hasLength(2));
      for (final variant in variants.cast<Map<String, Object?>>()) {
        expect(variant['additionalProperties'], isFalse);
        expect(variant['required'], ['kind', 'source']);
      }
    });

    test('a trigger def backs the sfx "at"', () {
      expect(defs()['trigger'], isA<Map<String, Object?>>());
    });

    test('video and scene audio are arrays of audioTrack', () {
      final root = videoSpecSchema['properties']! as Map<String, Object?>;
      final videoAudio = root['audio']! as Map<String, Object?>;
      expect((videoAudio['items']! as Map<String, Object?>)[r'$ref'], r'#/$defs/audioTrack');
      final scene = defs()['scene']! as Map<String, Object?>;
      final sceneAudio =
          (scene['properties']! as Map<String, Object?>)['audio']! as Map<String, Object?>;
      expect((sceneAudio['items']! as Map<String, Object?>)[r'$ref'], r'#/$defs/audioTrack');
    });
  });
}
