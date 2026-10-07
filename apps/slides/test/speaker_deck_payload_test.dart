import 'package:flutter_test/flutter_test.dart';
import 'package:slides/routing/speaker_deck_payload.dart';

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': 'hd',
  'fps': 30,
  'audio': [
    {
      'kind': 'music',
      'source': {'kind': 'bundle', 'value': 'media/bed.mp3'},
    },
  ],
  'scenes': [
    {
      'duration': '60f',
      'children': [
        {
          'id': 'el-1',
          'type': 'Image',
          'source': {'kind': 'bundle', 'value': 'media/photo.png'},
        },
        {
          'id': 'el-2',
          'type': 'Clip',
          'source': {'kind': 'bundle', 'value': 'media/cam.mp4'},
          'poster': {'kind': 'bundle', 'value': 'media/poster.png'},
        },
        {
          'id': 'el-3',
          'type': 'Image',
          'source': {'kind': 'asset', 'value': 'stills/kept.png'},
        },
      ],
      'audio': [
        {
          'kind': 'sfx',
          'source': {'kind': 'bundle', 'value': 'media/pop.wav'},
        },
      ],
    },
  ],
};

void main() {
  group('speakerDeckPayload', () {
    test('rewrites bundle media to the minted session URLs, audio to asset form', () {
      final urls = <String>[];
      final rewritten = speakerDeckPayload(
        _deck(),
        urlFor: (value) {
          urls.add(value);
          return 'blob:fake/$value';
        },
      );

      final scene = (rewritten['scenes']! as List).single as Map<String, Object?>;
      final children = scene['children']! as List;
      expect((children[0] as Map<String, Object?>)['source'], {
        'kind': 'network',
        'value': 'blob:fake/media/photo.png',
      });
      final clip = children[1] as Map<String, Object?>;
      expect(clip['source'], {'kind': 'network', 'value': 'blob:fake/media/cam.mp4'});
      expect(clip['poster'], {'kind': 'network', 'value': 'blob:fake/media/poster.png'});
      // A non-bundle source travels untouched.
      expect((children[2] as Map<String, Object?>)['source'], {
        'kind': 'asset',
        'value': 'stills/kept.png',
      });

      // Audio never plays live in the popup, so its bundle values take the
      // asset form (the printer's precedent) — no URL is minted for them.
      final bed = (rewritten['audio']! as List).single as Map<String, Object?>;
      expect(bed['source'], {'kind': 'asset', 'value': 'media/bed.mp3'});
      final sfx = (scene['audio']! as List).single as Map<String, Object?>;
      expect(sfx['source'], {'kind': 'asset', 'value': 'media/pop.wav'});
      expect(urls, isNot(contains('media/bed.mp3')));
      expect(urls, isNot(contains('media/pop.wav')));
    });

    test('a value the session cannot mint falls back to the asset form', () {
      final rewritten = speakerDeckPayload(_deck(), urlFor: (_) => null);
      final scene = (rewritten['scenes']! as List).single as Map<String, Object?>;
      final children = scene['children']! as List;
      expect((children[0] as Map<String, Object?>)['source'], {
        'kind': 'asset',
        'value': 'media/photo.png',
      });
    });

    test('never mutates the input document', () {
      final deck = _deck();
      speakerDeckPayload(deck, urlFor: (value) => 'blob:fake/$value');
      expect(deck, _deck());
    });

    test('a deck with no bundle references passes through unchanged', () {
      final deck = {
        'fluvieSpec': 1,
        'scenes': [
          {
            'duration': '60f',
            'children': [
              {
                'id': 'el-1',
                'type': 'Image',
                'source': {'kind': 'file', 'value': '/photo.png'},
              },
            ],
          },
        ],
      };
      expect(speakerDeckPayload(deck, urlFor: (_) => 'never'), deck);
    });
  });
}
