import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/audio/audio.dart';
import 'package:fluvie/src/audio/encoding/resolved_audio_track.dart';
import 'package:fluvie/src/rendering/audio_sandbox_staging.dart';
import 'package:fluvie/src/rendering/io/memory_render_sandbox.dart';

void main() {
  Future<Uint8List> bytesFor(String source) async => Uint8List.fromList(utf8.encode(source));

  group('stageResolvedAudioToSandbox', () {
    test('writes each track to the sandbox under audio_<i>_<cacheKey>', () async {
      final sandbox = MemoryRenderSandbox();
      const tracks = [
        ResolvedAudioTrack(source: 'audio/song.mp3', volume: 0.8),
        ResolvedAudioTrack(source: 'audio/sfx.wav', delayMs: 500),
      ];

      final plan = await stageResolvedAudioToSandbox(
        tracks: tracks,
        sandbox: sandbox,
        loadBytes: bytesFor,
      );

      expect(plan.tracks, hasLength(2));
      expect(plan.amix, isNotNull);
      // Names match the desktop path: audio_<i>_<the AudioSource cacheKey>.
      final key0 = const Audio.music('audio/song.mp3').audioSource.cacheKey;
      expect(plan.tracks.first.name, 'audio_0_$key0');
      expect(await sandbox.readBytes('audio_0_$key0'), utf8.encode('audio/song.mp3'));
      expect(plan.tracks.first.volume, 0.8);
      expect(plan.tracks[1].delayMs, 500);
    });

    test('carries the loop flag onto the staged node', () async {
      final sandbox = MemoryRenderSandbox();
      const tracks = [ResolvedAudioTrack(source: 'audio/bed.wav', loop: true)];
      final plan = await stageResolvedAudioToSandbox(
        tracks: tracks,
        sandbox: sandbox,
        loadBytes: bytesFor,
      );
      expect(plan.tracks.single.loop, isTrue);
      expect(plan.tracks.single.inputArgs(), containsAllInOrder(['-stream_loop', '-1', '-i']));
    });

    test('applies the master volume to the amix', () async {
      final sandbox = MemoryRenderSandbox();
      const tracks = [ResolvedAudioTrack(source: 'audio/song.mp3')];
      final plan = await stageResolvedAudioToSandbox(
        tracks: tracks,
        sandbox: sandbox,
        loadBytes: bytesFor,
        masterVolume: 0.5,
      );
      expect(
        plan.amix!.mixChain(labels: ['a0'], outLabel: 'aout'),
        contains('volume=0.5'),
      );
    });

    test('an empty track list stages nothing and yields an empty plan', () async {
      final sandbox = MemoryRenderSandbox();
      final plan = await stageResolvedAudioToSandbox(
        tracks: const [],
        sandbox: sandbox,
        loadBytes: bytesFor,
      );
      expect(plan.isEmpty, isTrue);
      expect(plan.amix, isNull);
      expect(sandbox.names, isEmpty);
    });
  });
}
