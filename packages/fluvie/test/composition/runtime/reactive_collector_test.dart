import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/audio/audio.dart';
import 'package:fluvie/src/composition/runtime/reactive_collector.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/time.dart';

Video _video(List<Audio> audio) => Video(
  scenes: const [Scene(duration: Time.seconds(2))],
  audio: audio,
);

void main() {
  group('collectReactiveTracks', () {
    test('maps each tracked audio anchor to its source', () {
      final beat = Anchor('beat');
      final video = _video([Audio.music('song.mp3', track: beat)]);
      final tracks = collectReactiveTracks(video);
      expect(tracks.byAnchor.keys, contains(beat));
      expect(tracks.byAnchor[beat], const AudioSource.asset('song.mp3'));
    });

    test('exposes the default source (the first declared track)', () {
      final video = _video([
        const Audio.music('first.mp3'),
        const Audio.music('second.mp3'),
      ]);
      final tracks = collectReactiveTracks(video);
      expect(tracks.defaultSource, const AudioSource.asset('first.mp3'));
    });

    test('an untracked-only composition still exposes a default source', () {
      final video = _video([const Audio.music('only.mp3')]);
      final tracks = collectReactiveTracks(video);
      expect(tracks.defaultSource, const AudioSource.asset('only.mp3'));
      expect(tracks.byAnchor, isEmpty);
    });

    test('a silent composition has no default source and no tracks', () {
      final video = _video(const []);
      final tracks = collectReactiveTracks(video);
      expect(tracks.defaultSource, isNull);
      expect(tracks.byAnchor, isEmpty);
      expect(tracks.allSources, isEmpty);
    });

    test('allSources deduplicates the default and the tracked sources', () {
      final beat = Anchor('beat');
      final video = _video([Audio.music('song.mp3', track: beat)]);
      final tracks = collectReactiveTracks(video);
      expect(tracks.allSources, {const AudioSource.asset('song.mp3')});
    });
  });
}
