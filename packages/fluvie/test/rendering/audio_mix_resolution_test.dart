import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';

void main() {
  group('resolveAudioMix', () {
    test('a video with no audio resolves to an empty mix', () {
      final video = Video(
        size: VideoSize.square,
        scenes: [Scene(duration: 2.seconds)],
      );
      final mix = resolveAudioMix(video: video, fps: 30, totalFrames: 60);
      expect(mix.isEmpty, isTrue);
      expect(mix.tracks, isEmpty);
      expect(mix.masterVolume, 1);
    });

    test('a music bed resolves to a track with its source and gain', () {
      final video = Video(
        size: VideoSize.square,
        audio: const [Audio.music('audio/song.mp3', volume: 0.8, fadeIn: Time.frames(30))],
        scenes: [Scene(duration: 2.seconds)],
      );

      final mix = resolveAudioMix(video: video, fps: 30, totalFrames: 180);

      expect(mix.tracks, hasLength(1));
      final track = mix.tracks.single;
      expect(track.source, 'audio/song.mp3');
      expect(track.volume, 0.8);
      expect(track.fadeInSeconds, 1.0);
      expect(track.delayMs, 0);
      expect(track.loop, isFalse);
    });

    test('matches the FFmpeg mix timing: trim, fade-out anchor, and sfx delay', () {
      final video = Video(
        size: VideoSize.square,
        audio: [
          Audio.music('audio/song.mp3', trim: 0.seconds.to(2.seconds), fadeOut: 15.frames),
          Audio.sfx('audio/ping.wav', at: Trigger.at(1.seconds)),
        ],
        scenes: [Scene(duration: 6.seconds)],
      );

      final mix = resolveAudioMix(video: video, fps: 30, totalFrames: 180);

      final music = mix.tracks[0];
      expect(music.source, 'audio/song.mp3');
      expect(music.trimStartSeconds, 0.0);
      expect(music.trimEndSeconds, 2.0);
      // A 0.5 s fade-out ends at the 2 s trim, so it begins at 1.5 s.
      expect(music.fadeOutStartSeconds, 1.5);

      final sfx = mix.tracks[1];
      expect(sfx.source, 'audio/ping.wav');
      expect(sfx.delayMs, 1000); // Trigger.at(1.seconds) at 30 fps
    });
  });
}
