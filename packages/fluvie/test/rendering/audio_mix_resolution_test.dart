import 'dart:typed_data';

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

    test('the typed source rides every resolved declared track', () {
      final bytes = Uint8List.fromList(const [1, 2, 3]);
      final memory = AudioSource.memory(bytes, debugLabel: 'bed.mp3');
      final video = Video(
        size: VideoSize.square,
        audio: [
          Audio.musicSource(memory, volume: 0.6, fadeIn: 30.frames),
          const Audio.music('audio/song.mp3'),
        ],
        scenes: [Scene(duration: 2.seconds)],
      );

      final mix = resolveAudioMix(video: video, fps: 30, totalFrames: 60);

      // The memory bed keeps its bytes: no string round-trip, no throw.
      expect(mix.tracks[0].audioSource, same(memory));
      expect(mix.tracks[0].source, 'memory:${memory.cacheKey}');
      expect(mix.tracks[0].volume, 0.6);
      expect(mix.tracks[0].fadeInSeconds, 1.0);
      // A string bed resolves its classified source alongside the string.
      expect(mix.tracks[1].audioSource, const AudioSource.asset('audio/song.mp3'));
    });

    test('a clip contributes a typed embedded-audio arm', () {
      final video = Video(
        size: VideoSize.square,
        scenes: [
          Scene(duration: 2.seconds),
          Scene(duration: 2.seconds, children: [Clip.asset('clips/cam.mp4')]),
        ],
      );

      final mix = resolveAudioMix(video: video, fps: 30, totalFrames: 120);

      final track = mix.tracks.single;
      expect(track.source, 'clips/cam.mp4');
      expect(track.audioSource, const AudioSource.asset('clips/cam.mp4'));
      expect(track.delayMs, 2000); // The clip plays in the second scene.
      expect(track.trimStartSeconds, 0.0);
      expect(track.trimEndSeconds, 2.0);
    });

    test('an overlapping transition delays a later clip by the shifted scene start', () {
      // An overlapping crossFade starts the next scene early:
      // start[1] = D0 - F0 = 60 - 15 = 45 frames, so 1500 ms at 30 fps.
      // Summing durations instead would delay the audio to 2000 ms, half a
      // second after the picture.
      final video = Video(
        size: VideoSize.square,
        transition: const Transition.crossFade(Time.frames(15)),
        scenes: [
          Scene(duration: 2.seconds),
          Scene(duration: 2.seconds, children: [Clip.asset('clips/cam.mp4')]),
        ],
      );

      expect(video.sceneStartFrames, [0, 45]);

      final mix = resolveAudioMix(video: video, fps: 30, totalFrames: video.totalFrames);

      expect(mix.tracks.single.delayMs, 1500);
    });

    test('a windowed clip is heard when it appears, not when its scene starts', () {
      final video = Video(
        size: VideoSize.square,
        scenes: [
          Scene(
            duration: 5.seconds,
            children: [
              Clip.asset('clips/cam.mp4').show(from: 1.seconds, to: 2.seconds),
            ],
          ),
        ],
      );

      final track = resolveAudioMix(video: video, fps: 30, totalFrames: 150).tracks.single;

      expect(track.delayMs, 1000);
      expect(track.trimEndSeconds, 1.0, reason: 'it plays for its window, not the whole scene');
    });

    test('a trimmed clip opens its audio at the trim, given the probed source', () {
      final video = Video(
        size: VideoSize.square,
        scenes: [
          Scene(
            duration: 3.seconds,
            children: [Clip.asset('clips/cam.mp4', trim: 2.seconds.to(7.seconds))],
          ),
        ],
      );

      final mix = resolveAudioMix(
        video: video,
        fps: 30,
        totalFrames: 90,
        // A 10 s source at 30 fps: the trim is source frames 60..210.
        clipMetadata: (_) => (fps: 30.0, frameCount: 300, width: 16, height: 9, hasAudio: true),
      );

      final track = mix.tracks.single;
      expect(track.trimStartSeconds, 2.0);
      expect(track.trimEndSeconds, 5.0); // 2 s in, for the 3 s the clip is shown
    });

    test('a trimmed clip with no probed source refuses rather than desyncing', () {
      final video = Video(
        size: VideoSize.square,
        scenes: [
          Scene(
            duration: 3.seconds,
            children: [Clip.asset('clips/cam.mp4', trim: 2.seconds.to(7.seconds))],
          ),
        ],
      );

      expect(
        () => resolveAudioMix(video: video, fps: 30, totalFrames: 90),
        throwsA(
          isA<FluvieRenderException>().having(
            (error) => error.message,
            'message',
            allOf(contains('clips/cam.mp4'), contains('clipMetadata')),
          ),
        ),
        reason:
            'resolveAudioMix is pure, so it cannot probe. Without the probed '
            'source it cannot place a trimmed clip and must say so instead of '
            'silently starting the audio at zero.',
      );
    });

    test('a memory clip contributes its embedded audio with its bytes', () {
      final bytes = Uint8List.fromList(const [7, 7, 7]);
      final video = Video(
        size: VideoSize.square,
        scenes: [
          Scene(
            duration: 2.seconds,
            children: [Clip.memory(bytes, debugLabel: 'media/cam.mp4')],
          ),
        ],
      );

      final mix = resolveAudioMix(video: video, fps: 30, totalFrames: 60);

      final track = mix.tracks.single;
      final source = track.audioSource;
      expect(source, isA<MemoryAudioSource>());
      expect((source! as MemoryAudioSource).bytes, same(bytes));
      // The string form is the stable diagnostic label, like a memory bed's.
      expect(track.source, 'memory:${source.cacheKey}');
      expect(track.trimEndSeconds, 2.0);
    });

    test('a memory clip arm stages into the sandbox and joins the amix graph', () async {
      final bytes = Uint8List.fromList(const [1, 2, 3, 4]);
      final video = Video(
        size: VideoSize.square,
        audio: const [Audio.music('audio/bed.mp3')],
        scenes: [
          Scene(
            duration: 2.seconds,
            children: [Clip.memory(bytes, debugLabel: 'media/cam.mp4')],
          ),
        ],
      );
      final mix = resolveAudioMix(video: video, fps: 30, totalFrames: 60);
      expect(mix.tracks, hasLength(2));

      final sandbox = MemoryRenderSandbox();
      final plan = await stageResolvedAudioToSandbox(
        tracks: mix.tracks,
        sandbox: sandbox,
        loadBytes: (source) async => Uint8List.fromList(source.codeUnits),
      );

      // The memory clip's bytes land under their content hash and the mix
      // graph gains its arm — the filter-graph pin, no encoder involved.
      final clipKey = AudioSource.memory(bytes).cacheKey;
      expect(await sandbox.readBytes('audio_1_$clipKey'), bytes);
      final graph = plan.amix!.mixChain(labels: const ['a0', 'a1'], outLabel: 'aout');
      expect(graph, contains('amix=inputs=2'));
    });
  });
}
