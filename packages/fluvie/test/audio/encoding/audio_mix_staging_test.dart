import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/audio/audio.dart';
import 'package:fluvie/src/audio/encoding/audio_mix_staging.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/time_range.dart';

import '../../rendering/fakes/fake_media_resolver.dart';

void main() {
  late Directory sandbox;
  late Directory srcDir;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('fluvie_mix_stage_');
    srcDir = await Directory.systemTemp.createTemp('fluvie_mix_src_');
  });

  tearDown(() {
    for (final dir in [sandbox, srcDir]) {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    }
  });

  String materialize(String name, List<int> bytes) {
    final file = File('${srcDir.path}/$name')..writeAsBytesSync(bytes);
    return file.path;
  }

  group('stageAudioMix', () {
    test('a single music track stages a sandbox file and one mapped node', () async {
      const song = AudioSource.asset('audio/song.mp3');
      final resolver = FakeMediaResolver(
        const {},
        audioPaths: {
          song: materialize('song.bin', const [1, 2, 3, 4]),
        },
      );
      await resolver.preResolveAudio(const [song]);

      final plan = await stageAudioMix(
        tracks: const [Audio.music('audio/song.mp3')],
        resolver: resolver,
        sandbox: sandbox,
        fps: 30,
      );

      expect(plan.tracks, hasLength(1));
      expect(plan.amix, isNotNull);
      // A plain music track does not loop, so its input stays a bare -i.
      expect(plan.tracks.single.loop, isFalse);
      // The node points at a bare sandbox-relative name, never an absolute path.
      final name = plan.tracks.single.name;
      expect(name, isNot(contains('/')));
      expect(File('${sandbox.path}/$name').existsSync(), isTrue);
      expect(File('${sandbox.path}/$name').readAsBytesSync(), const [1, 2, 3, 4]);
    });

    test('the music fades flow onto the node in seconds, fade-out end-anchored', () async {
      const song = AudioSource.asset('audio/song.mp3');
      final resolver = FakeMediaResolver(
        const {},
        audioPaths: {
          song: materialize('song.bin', const [0]),
        },
      );
      await resolver.preResolveAudio(const [song]);

      final plan = await stageAudioMix(
        tracks: [
          Audio.music('audio/song.mp3', volume: 0.8, fadeIn: 30.frames, fadeOut: 15.frames),
        ],
        resolver: resolver,
        sandbox: sandbox,
        fps: 30,
        totalFrames: 180, // a 6 s composition
      );

      final node = plan.tracks.single;
      expect(node.volume, 0.8);
      expect(node.fadeInSeconds, 1.0);
      expect(node.fadeOutSeconds, 0.5);
      // The fade-out must land at the END of the 6 s window (st = 6 - 0.5), not
      // at st = 0, which would mute the whole bed (the silent-render bug).
      expect(node.fadeOutStartSeconds, 5.5);
      expect(
        node.filterChain(inputIndex: 1, label: 'a0'),
        contains('afade=t=out:st=5.5:d=0.5'),
      );
    });

    test('a non-looping trim anchors the fade-out at the trimmed length', () async {
      const song = AudioSource.asset('audio/song.mp3');
      final resolver = FakeMediaResolver(
        const {},
        audioPaths: {
          song: materialize('song.bin', const [0]),
        },
      );
      await resolver.preResolveAudio(const [song]);

      final plan = await stageAudioMix(
        tracks: [
          // A 2 s trim on a 6 s composition: the audio ends at 2 s, so the
          // 0.5 s fade-out begins at 1.5 s, not 5.5 s.
          Audio.music('audio/song.mp3', trim: 0.seconds.to(2.seconds), fadeOut: 15.frames),
        ],
        resolver: resolver,
        sandbox: sandbox,
        fps: 30,
        totalFrames: 180,
      );

      expect(plan.tracks.single.fadeOutStartSeconds, 1.5);
    });

    test('a looping bed fills the window so the fade-out stays window-anchored', () async {
      const song = AudioSource.asset('audio/song.mp3');
      final resolver = FakeMediaResolver(
        const {},
        audioPaths: {
          song: materialize('song.bin', const [0]),
        },
      );
      await resolver.preResolveAudio(const [song]);

      final plan = await stageAudioMix(
        tracks: [
          // Looping ignores the short trim: the bed fills the 6 s window, so the
          // fade-out still lands at 5.5 s.
          Audio.music(
            'audio/song.mp3',
            loop: true,
            trim: 0.seconds.to(2.seconds),
            fadeOut: 15.frames,
          ),
        ],
        resolver: resolver,
        sandbox: sandbox,
        fps: 30,
        totalFrames: 180,
      );

      expect(plan.tracks.single.fadeOutStartSeconds, 5.5);
      // A looping bed WITH a trim repeats the trimmed window in-filter (aloop),
      // not at the input, so the trim is what loops and fills the window.
      expect(plan.tracks.single.loop, isTrue);
      expect(plan.tracks.single.inputArgs(), isNot(contains('-stream_loop')));
      expect(plan.tracks.single.filterChain(inputIndex: 1, label: 'a0'), contains('aloop=loop=-1'));
    });

    test('a music trim resolves onto the node as start/end seconds', () async {
      const song = AudioSource.asset('audio/song.mp3');
      final resolver = FakeMediaResolver(
        const {},
        audioPaths: {
          song: materialize('song.bin', const [0]),
        },
      );
      await resolver.preResolveAudio(const [song]);

      final plan = await stageAudioMix(
        tracks: [
          Audio.music('audio/song.mp3', trim: 2.seconds.to(10.seconds)),
        ],
        resolver: resolver,
        sandbox: sandbox,
        fps: 30,
      );

      final node = plan.tracks.single;
      expect(node.trimStartSeconds, 2.0); // 60 frames @ 30fps
      expect(node.trimEndSeconds, 10.0); // 300 frames @ 30fps
    });

    test('a silent composition stages nothing and yields an empty plan', () async {
      final resolver = FakeMediaResolver(const {});
      final plan = await stageAudioMix(
        tracks: const [],
        resolver: resolver,
        sandbox: sandbox,
        fps: 30,
      );
      expect(plan.isEmpty, isTrue);
      expect(plan.amix, isNull);
      expect(sandbox.listSync(), isEmpty);
    });

    test('the staged plan is deterministic (same tracks yield equal arg arrays)', () async {
      const song = AudioSource.asset('audio/song.mp3');
      Future<List<String>> argsOnce() async {
        final resolver = FakeMediaResolver(
          const {},
          audioPaths: {
            song: materialize('song.bin', const [9]),
          },
        );
        await resolver.preResolveAudio(const [song]);
        final plan = await stageAudioMix(
          tracks: const [Audio.music('audio/song.mp3')],
          resolver: resolver,
          sandbox: sandbox,
          fps: 30,
        );
        return [
          for (final track in plan.tracks) track.filterChain(inputIndex: 1, label: 'a0'),
        ];
      }

      expect(await argsOnce(), await argsOnce());
    });
  });
}
