import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/audio/audio.dart';
import 'package:fluvie/src/composition/runtime/audio_collector.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/trigger.dart';

void main() {
  Scene scene({List<Audio> audio = const []}) =>
      Scene(duration: 1.seconds, audio: audio, children: const [SizedBox()]);

  group('collectAudioTracks', () {
    test('gathers video-level music tracks', () {
      final video = Video(
        scenes: [scene()],
        audio: const [Audio.music('audio/song.mp3')],
      );
      expect(collectAudioTracks(video), hasLength(1));
      expect(collectAudioTracks(video).single.source, 'audio/song.mp3');
    });

    test('gathers scene-level tracks after video-level ones, in scene order', () {
      final video = Video(
        scenes: [
          scene(audio: const [Audio.music('audio/scene0.mp3')]),
          scene(audio: const [Audio.sfx('audio/pop.wav')]),
        ],
        audio: const [Audio.music('audio/bed.mp3')],
      );
      final tracks = collectAudioTracks(video);
      expect(
        [for (final track in tracks) track.source],
        ['audio/bed.mp3', 'audio/scene0.mp3', 'audio/pop.wav'],
      );
    });

    test('a silent composition yields no tracks', () {
      expect(collectAudioTracks(Video(scenes: [scene()])), isEmpty);
    });
  });

  group('collectAudioSources', () {
    test('resolves each track to a deduplicated AudioSource', () {
      final video = Video(
        scenes: [scene()],
        audio: const [
          Audio.music('audio/song.mp3'),
          Audio.sfx('audio/song.mp3'),
        ],
      );
      final sources = collectAudioSources(video);
      expect(sources, {const AudioSource.asset('audio/song.mp3')});
    });

    test('distinguishes a file from an asset of the same string', () {
      final video = Video(
        scenes: [scene()],
        audio: const [
          Audio.music('/abs/song.mp3'),
          Audio.music('audio/song.mp3'),
        ],
      );
      expect(collectAudioSources(video), hasLength(2));
    });

    test('a one-shot with a trigger still resolves to its source', () {
      final video = Video(
        scenes: [scene()],
        audio: [Audio.sfx('audio/pop.wav', at: Trigger.at(1.seconds))],
      );
      expect(collectAudioSources(video), {const AudioSource.asset('audio/pop.wav')});
    });
  });
}
