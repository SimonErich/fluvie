import 'dart:typed_data';

import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart'
    show AudioTrackSpec, BundleMedia, Clip, Image, MediaSource, VideoSpec;
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/serialization/anchor_table.dart';
import 'package:fluvie/src/serialization/element_spec.dart';

Object _build(Map<String, Object?> json) {
  final spec = ElementSpec.fromJson(json, AnchorTable());
  expect(spec.toJson(), json, reason: 'the codec round-trip is identity');
  final built = spec.build(AnchorTable());
  return built is SizedBox ? built.child! : built;
}

void main() {
  final pngBytes = Uint8List.fromList([1, 2, 3, 4]);
  final mp4Bytes = Uint8List.fromList([5, 6, 7, 8]);
  final bundle = BundleMedia(
    media: {
      'media/photo.png': MediaSource.memory(pngBytes, debugLabel: 'photo.png'),
      'media/b-roll.mp4': MediaSource.memory(mp4Bytes, debugLabel: 'b-roll.mp4'),
    },
    audio: {
      'media/bed.mp3': AudioSource.memory(Uint8List.fromList([9]), debugLabel: 'bed.mp3'),
    },
  );

  tearDown(() => BundleMedia.current = null);

  group('BundleMedia scoping', () {
    test('current is null by default and settable for a loader session', () {
      expect(BundleMedia.current, isNull);
      BundleMedia.current = bundle;
      expect(BundleMedia.current, same(bundle));
    });

    test('resolve scopes the bundle and restores the previous one, even on a throw', () {
      final outer = BundleMedia();
      BundleMedia.current = outer;
      final seen = BundleMedia.resolve(bundle, () => BundleMedia.current);
      expect(seen, same(bundle));
      expect(BundleMedia.current, same(outer));
      expect(
        () => BundleMedia.resolve(bundle, () => throw StateError('boom')),
        throwsStateError,
      );
      expect(BundleMedia.current, same(outer));
    });

    test('mediaFor and audioFor name a missing entry and the known ones', () {
      expect(
        () => bundle.mediaFor('media/missing.png'),
        throwsA(
          isA<FluvieSpecError>().having(
            (e) => e.message,
            'message',
            allOf(contains('media/missing.png'), contains('media/photo.png')),
          ),
        ),
      );
      expect(
        () => bundle.audioFor('media/missing.mp3'),
        throwsA(
          isA<FluvieSpecError>().having(
            (e) => e.message,
            'message',
            allOf(contains('media/missing.mp3'), contains('media/bed.mp3')),
          ),
        ),
      );
    });
  });

  group('bundle image and clip sources', () {
    final imageJson = {
      'type': 'Image',
      'source': {'kind': 'bundle', 'value': 'media/photo.png'},
    };
    final clipJson = {
      'type': 'Clip',
      'source': {'kind': 'bundle', 'value': 'media/b-roll.mp4'},
      'poster': {'kind': 'bundle', 'value': 'media/photo.png'},
    };

    test('build without a bundle in scope throws naming the missing context', () {
      expect(
        () => _build(imageJson),
        throwsA(
          isA<FluvieSpecError>().having(
            (e) => e.message,
            'message',
            allOf(contains('media/photo.png'), contains('bundle')),
          ),
        ),
      );
    });

    test('an image resolves through the scope to the materialized source', () {
      final widget = BundleMedia.resolve(bundle, () => _build(imageJson)) as Image;
      expect(widget.source, MediaSource.memory(pngBytes, debugLabel: 'photo.png'));
    });

    test('a clip and its poster resolve through the scope', () {
      final widget = BundleMedia.resolve(bundle, () => _build(clipJson)) as Clip;
      expect(widget.source, MediaSource.memory(mp4Bytes, debugLabel: 'b-roll.mp4'));
      expect(widget.poster, MediaSource.memory(pngBytes, debugLabel: 'photo.png'));
    });

    test('a desktop-style scope resolves the same values to files', () {
      final onDisk = BundleMedia(
        media: {'media/photo.png': const MediaSource.file('/tmp/unpack/media/photo.png')},
      );
      final widget = BundleMedia.resolve(onDisk, () => _build(imageJson)) as Image;
      expect(widget.source, const MediaSource.file('/tmp/unpack/media/photo.png'));
    });

    test('the JSON form and the digest stay bundle-relative under any scope', () {
      final doc = {
        'fluvieSpec': 1,
        'size': {'width': 100, 'height': 100},
        'fps': 30,
        'scenes': [
          {
            'duration': '30f',
            'children': [imageJson],
          },
        ],
      };
      final bare = VideoSpec.fromJson(doc);
      final scoped = BundleMedia.resolve(bundle, () => VideoSpec.fromJson(doc));
      expect(bare.toJson(), doc);
      expect(scoped.toJson(), doc);
      expect(scoped.digest(), bare.digest());
    });

    test('a memory kind still has no JSON form', () {
      expect(
        () => _build({
          'type': 'Image',
          'source': {'kind': 'memory', 'value': 'x'},
        }),
        throwsA(isA<FluvieSpecError>()),
      );
    });
  });

  group('Clip.memory', () {
    test('carries verbatim bytes like Image.memory', () {
      final clip = Clip.memory(mp4Bytes, debugLabel: 'b-roll.mp4');
      expect(clip.source, MediaSource.memory(mp4Bytes, debugLabel: 'b-roll.mp4'));
    });
  });

  group('bundle audio sources', () {
    final musicJson = {
      'kind': 'music',
      'source': {'kind': 'bundle', 'value': 'media/bed.mp3'},
    };

    test('a music track parses unresolved and round-trips the bundle form', () {
      final track = AudioTrackSpec.fromJson(musicJson, AnchorTable());
      expect(track.bundle, 'media/bed.mp3');
      expect(track.toJson(), musicJson);
    });

    test('an sfx track carries a bundle source the same way', () {
      final json = {
        'kind': 'sfx',
        'source': {'kind': 'bundle', 'value': 'media/pop.wav'},
      };
      final track = AudioTrackSpec.fromJson(json, AnchorTable());
      expect(track.bundle, 'media/pop.wav');
      expect(track.toJson(), json);
    });

    test('reading the source without a bundle in scope names the missing context', () {
      final track = AudioTrackSpec.fromJson(musicJson, AnchorTable());
      expect(
        () => track.source,
        throwsA(
          isA<FluvieSpecError>().having(
            (e) => e.message,
            'message',
            allOf(contains('media/bed.mp3'), contains('bundle')),
          ),
        ),
      );
    });

    test('a desktop-style scope resolves the source and builds a playable Audio', () {
      final onDisk = BundleMedia(
        audio: {'media/bed.mp3': const AudioSource.file('/tmp/unpack/media/bed.mp3')},
      );
      BundleMedia.resolve(onDisk, () {
        final track = AudioTrackSpec.fromJson(musicJson, AnchorTable());
        expect(track.source, const AudioSource.file('/tmp/unpack/media/bed.mp3'));
        expect(track.build().source, '/tmp/unpack/media/bed.mp3');
      });
    });

    test('a memory scope builds an Audio that carries the bytes to the mix', () {
      BundleMedia.resolve(bundle, () {
        final track = AudioTrackSpec.fromJson(musicJson, AnchorTable());
        expect(track.source, isA<MemoryAudioSource>());
        // The 9.6 export law: web-imported audio (bytes, no path) builds and
        // reaches the encoder's collect pass as the same memory source.
        final audio = track.build();
        expect(audio.audioSource, track.source);
        expect((audio.audioSource as MemoryAudioSource).debugLabel, 'bed.mp3');
      });
    });

    test('an empty bundle value is a parse error', () {
      expect(
        () => AudioTrackSpec.fromJson({
          'kind': 'music',
          'source': {'kind': 'bundle', 'value': ''},
        }, AnchorTable()),
        throwsA(isA<FluvieSpecError>()),
      );
    });

    test('the constructors take exactly one of source and bundle', () {
      expect(AudioTrackSpec.music, throwsArgumentError);
      expect(
        () => AudioTrackSpec.sfx(
          source: const AudioSource.asset('a.mp3'),
          bundle: 'media/a.mp3',
        ),
        throwsArgumentError,
      );
      expect(AudioTrackSpec.music(bundle: 'media/a.mp3').bundle, 'media/a.mp3');
    });

    test('the digest counts a bundle audio source and stays scope-independent', () {
      final doc = {
        'fluvieSpec': 1,
        'size': {'width': 100, 'height': 100},
        'fps': 30,
        'audio': [musicJson],
        'scenes': [
          {'duration': '30f'},
        ],
      };
      final bare = VideoSpec.fromJson(doc);
      final scoped = BundleMedia.resolve(bundle, () => VideoSpec.fromJson(doc));
      expect(bare.toJson(), doc);
      expect(scoped.digest(), bare.digest());
      final silent = VideoSpec.fromJson({...doc}..remove('audio'));
      expect(silent.digest(), isNot(bare.digest()));
    });
  });
}
