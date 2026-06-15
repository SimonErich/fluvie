// Epic 14.5 (WI-23, D-SfxWiring): stageAudioMix threads each sfx track's
// resolved `at:` trigger frame into its AudioTrackNode.delayMs (= frame / fps *
// 1000 ms), closing Audio.sfx(at:) (AUDMIX-2). A music track carries no delay
// (regression), and an sfx with no/zero `at:` stays at delayMs 0.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/audio/audio.dart';
import 'package:fluvie/src/audio/encoding/audio_mix_staging.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/trigger.dart';

import '../../rendering/fakes/fake_media_resolver.dart';

void main() {
  late Directory sandbox;
  late Directory srcDir;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('fluvie_mix_sfx_');
    srcDir = await Directory.systemTemp.createTemp('fluvie_mix_sfx_src_');
  });

  tearDown(() {
    for (final dir in [sandbox, srcDir]) {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    }
  });

  Future<FakeMediaResolver> resolverFor(AudioSource source, String fileName) async {
    final file = File('${srcDir.path}/$fileName')..writeAsBytesSync(const [1, 2, 3]);
    final resolver = FakeMediaResolver(const {}, audioPaths: {source: file.path});
    await resolver.preResolveAudio([source]);
    return resolver;
  }

  group('stageAudioMix — the sfx delay (WI-23)', () {
    test('an sfx at 1s stages adelay=1000|1000 at 30fps', () async {
      const pop = AudioSource.asset('audio/pop.wav');
      final resolver = await resolverFor(pop, 'pop.bin');

      final plan = await stageAudioMix(
        tracks: [Audio.sfx('audio/pop.wav', at: Trigger.at(1.seconds))],
        resolver: resolver,
        sandbox: sandbox,
        fps: 30,
        totalFrames: 300,
      );

      final node = plan.tracks.single;
      expect(node.delayMs, 1000);
      expect(node.filterChain(inputIndex: 1, label: 'a0'), contains('adelay=1000|1000'));
    });

    test('an sfx fired by an absolute frame resolves to the right ms', () async {
      const pop = AudioSource.asset('audio/pop.wav');
      final resolver = await resolverFor(pop, 'pop.bin');

      // Frame 15 @30fps = 500ms.
      final plan = await stageAudioMix(
        tracks: const [Audio.sfx('audio/pop.wav', at: Trigger.at(Time.frames(15)))],
        resolver: resolver,
        sandbox: sandbox,
        fps: 30,
        totalFrames: 300,
      );

      expect(plan.tracks.single.delayMs, 500);
    });

    test('an sfx with no at: has delayMs 0 (fires at the start)', () async {
      const pop = AudioSource.asset('audio/pop.wav');
      final resolver = await resolverFor(pop, 'pop.bin');

      final plan = await stageAudioMix(
        tracks: const [Audio.sfx('audio/pop.wav')],
        resolver: resolver,
        sandbox: sandbox,
        fps: 30,
        totalFrames: 300,
      );

      final node = plan.tracks.single;
      expect(node.delayMs, 0);
      expect(node.filterChain(inputIndex: 1, label: 'a0'), isNot(contains('adelay')));
    });

    test('an sfx fired at frame zero stays at delayMs 0', () async {
      const pop = AudioSource.asset('audio/pop.wav');
      final resolver = await resolverFor(pop, 'pop.bin');

      final plan = await stageAudioMix(
        tracks: const [Audio.sfx('audio/pop.wav', at: Trigger.at(Time.zero))],
        resolver: resolver,
        sandbox: sandbox,
        fps: 30,
        totalFrames: 300,
      );

      expect(plan.tracks.single.delayMs, 0);
    });

    test('a music track is never delayed (regression)', () async {
      const song = AudioSource.asset('audio/song.mp3');
      final resolver = await resolverFor(song, 'song.bin');

      final plan = await stageAudioMix(
        tracks: const [Audio.music('audio/song.mp3', volume: 0.8)],
        resolver: resolver,
        sandbox: sandbox,
        fps: 30,
        totalFrames: 300,
      );

      final node = plan.tracks.single;
      expect(node.delayMs, 0);
      expect(node.volume, 0.8);
    });

    test('a music + sfx mix delays only the sfx and is deterministic', () async {
      const song = AudioSource.asset('audio/song.mp3');
      const pop = AudioSource.asset('audio/pop.wav');

      Future<List<int>> delaysOnce() async {
        final dir = await Directory.systemTemp.createTemp('fluvie_mix_sfx_det_');
        final songFile = File('${dir.path}/song.bin')..writeAsBytesSync(const [1]);
        final popFile = File('${dir.path}/pop.bin')..writeAsBytesSync(const [2]);
        final resolver = FakeMediaResolver(
          const {},
          audioPaths: {song: songFile.path, pop: popFile.path},
        );
        await resolver.preResolveAudio(const [song, pop]);
        final out = await Directory.systemTemp.createTemp('fluvie_mix_sfx_out_');
        final plan = await stageAudioMix(
          tracks: [
            const Audio.music('audio/song.mp3'),
            Audio.sfx('audio/pop.wav', at: Trigger.at(2.seconds)),
          ],
          resolver: resolver,
          sandbox: out,
          fps: 30,
          totalFrames: 300,
        );
        addTearDown(() => dir.deleteSync(recursive: true));
        addTearDown(() => out.deleteSync(recursive: true));
        return [for (final node in plan.tracks) node.delayMs];
      }

      expect(await delaysOnce(), const [0, 2000]);
      expect(await delaysOnce(), await delaysOnce());
    });
  });
}
