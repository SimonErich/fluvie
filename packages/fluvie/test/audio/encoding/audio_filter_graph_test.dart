import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/audio/encoding/amix_node.dart';
import 'package:fluvie/src/audio/encoding/audio_track_node.dart';
import 'package:fluvie/src/audio/encoding/clip_audio_track.dart';
import 'package:fluvie/src/audio/encoding/resolved_audio_track.dart';
import 'package:fluvie/src/core/media/clip_audio.dart';
import 'package:fluvie/src/core/time.dart';

void main() {
  group('AudioTrackNode.inputArgs', () {
    test('emits a validated -i for the materialized file name', () {
      const node = AudioTrackNode(name: 'track0.wav');
      expect(node.inputArgs(), ['-i', 'track0.wav']);
    });

    test('rejects a path separator in the name (traversal)', () {
      expect(() => const AudioTrackNode(name: '../evil.wav').inputArgs(), throwsArgumentError);
    });

    test('rejects a name that would parse as a flag', () {
      expect(() => const AudioTrackNode(name: '-evil.wav').inputArgs(), throwsArgumentError);
    });

    test('rejects an empty name', () {
      expect(() => const AudioTrackNode(name: '').inputArgs(), throwsArgumentError);
    });

    test('an untrimmed looping track prefixes -stream_loop -1 before the -i', () {
      const node = AudioTrackNode(name: 'bed.wav', loop: true);
      expect(node.inputArgs(), ['-stream_loop', '-1', '-i', 'bed.wav']);
    });

    test('a trimmed looping track does NOT -stream_loop (it loops the trim in-filter)', () {
      const node = AudioTrackNode(
        name: 'bed.wav',
        loop: true,
        trimStartSeconds: 1,
        trimEndSeconds: 3,
      );
      expect(node.inputArgs(), ['-i', 'bed.wav']);
    });

    test('a non-looping track emits a bare -i (the default, unchanged)', () {
      const node = AudioTrackNode(name: 'bed.wav');
      expect(node.inputArgs(), ['-i', 'bed.wav']);
    });

    test('mapSpecifier addresses the node input audio stream by index', () {
      const node = AudioTrackNode(name: 'track0.wav');
      expect(node.mapSpecifier(1), '1:a');
      expect(node.mapSpecifier(3), '3:a');
    });
  });

  group('AudioTrackNode.filterChain', () {
    test('a bare track only resets pts and keeps unit volume', () {
      const node = AudioTrackNode(name: 't.wav');
      expect(
        node.filterChain(inputIndex: 1, label: 'a0'),
        '[1:a]asetpts=PTS-STARTPTS,volume=1[a0]',
      );
    });

    test('a delay emits an order-stable adelay in ms on both channels', () {
      const node = AudioTrackNode(name: 't.wav', delayMs: 1500);
      expect(
        node.filterChain(inputIndex: 1, label: 'a0'),
        '[1:a]asetpts=PTS-STARTPTS,adelay=1500|1500,volume=1[a0]',
      );
    });

    test('a trim emits atrim before the pts reset', () {
      const node = AudioTrackNode(name: 't.wav', trimStartSeconds: 2, trimEndSeconds: 10);
      expect(
        node.filterChain(inputIndex: 2, label: 'a1'),
        '[2:a]atrim=start=2:end=10,asetpts=PTS-STARTPTS,volume=1[a1]',
      );
    });

    test('volume is applied with the track gain', () {
      const node = AudioTrackNode(name: 't.wav', volume: 0.5);
      expect(
        node.filterChain(inputIndex: 1, label: 'a0'),
        '[1:a]asetpts=PTS-STARTPTS,volume=0.5[a0]',
      );
    });

    test('a fade-in emits afade t=in after volume', () {
      const node = AudioTrackNode(name: 't.wav', fadeInSeconds: 1);
      expect(
        node.filterChain(inputIndex: 1, label: 'a0'),
        '[1:a]asetpts=PTS-STARTPTS,volume=1,afade=t=in:st=0:d=1[a0]',
      );
    });

    test('a fade-out emits afade t=out', () {
      const node = AudioTrackNode(name: 't.wav', fadeOutSeconds: 2, fadeOutStartSeconds: 8);
      expect(
        node.filterChain(inputIndex: 1, label: 'a0'),
        '[1:a]asetpts=PTS-STARTPTS,volume=1,afade=t=out:st=8:d=2[a0]',
      );
    });

    test('a trimmed loop inserts aloop after the trim so the window repeats', () {
      const node = AudioTrackNode(
        name: 't.wav',
        loop: true,
        trimStartSeconds: 0,
        trimEndSeconds: 2,
      );
      expect(
        node.filterChain(inputIndex: 1, label: 'a0'),
        '[1:a]atrim=start=0:end=2,asetpts=PTS-STARTPTS,aloop=loop=-1:size=1073741824,volume=1[a0]',
      );
    });

    test('an untrimmed loop carries no aloop (the input -stream_loop does it)', () {
      const node = AudioTrackNode(name: 't.wav', loop: true);
      expect(node.filterChain(inputIndex: 1, label: 'a0'), isNot(contains('aloop')));
    });

    test('the full chain orders atrim, asetpts, adelay, volume, fades', () {
      const node = AudioTrackNode(
        name: 't.wav',
        delayMs: 500,
        trimStartSeconds: 1,
        trimEndSeconds: 9,
        volume: 0.8,
        fadeInSeconds: 1,
        fadeOutSeconds: 1.5,
        fadeOutStartSeconds: 7,
      );
      expect(
        node.filterChain(inputIndex: 3, label: 'a2'),
        '[3:a]atrim=start=1:end=9,asetpts=PTS-STARTPTS,adelay=500|500,volume=0.8,'
        'afade=t=in:st=0:d=1,afade=t=out:st=7:d=1.5[a2]',
      );
    });
  });

  group('AudioTrackNode.fromResolved', () {
    test('carries every resolved field onto the node under the given name', () {
      const resolved = ResolvedAudioTrack(
        source: 'audio/bed.wav',
        delayMs: 500,
        volume: 0.8,
        trimStartSeconds: 1,
        trimEndSeconds: 9,
        fadeInSeconds: 1,
        fadeOutSeconds: 1.5,
        fadeOutStartSeconds: 7,
        loop: true,
      );
      final node = AudioTrackNode.fromResolved(resolved, name: 'audio_0_abc');
      expect(node.name, 'audio_0_abc');
      expect(node.delayMs, 500);
      expect(node.volume, 0.8);
      expect(node.trimStartSeconds, 1);
      expect(node.trimEndSeconds, 9);
      expect(node.fadeInSeconds, 1);
      expect(node.fadeOutSeconds, 1.5);
      expect(node.fadeOutStartSeconds, 7);
      expect(node.loop, isTrue);
      // A trimmed loop repeats the trimmed window in-filter (aloop), so the input
      // is a bare -i and the chain carries an aloop after the trim.
      expect(node.inputArgs(), ['-i', 'audio_0_abc']);
      expect(node.filterChain(inputIndex: 1, label: 'a0'), contains('aloop=loop=-1'));
    });

    test('a non-looping resolution builds a bare-input node', () {
      const resolved = ResolvedAudioTrack(source: 'audio/song.mp3', volume: 0.5);
      final node = AudioTrackNode.fromResolved(resolved, name: 'audio_0_xyz');
      expect(node.loop, isFalse);
      expect(node.volume, 0.5);
      expect(node.inputArgs(), ['-i', 'audio_0_xyz']);
    });
  });

  group('AmixNode', () {
    test('combines N labelled inputs and applies a master volume', () {
      const amix = AmixNode(inputCount: 2);
      expect(
        amix.mixChain(labels: ['a0', 'a1'], outLabel: 'aout'),
        '[a0][a1]amix=inputs=2:normalize=0,volume=1[aout]',
      );
    });

    test('applies a non-unit master volume', () {
      const amix = AmixNode(inputCount: 1, masterVolume: 0.6);
      expect(
        amix.mixChain(labels: ['a0'], outLabel: 'aout'),
        '[a0]amix=inputs=1:normalize=0,volume=0.6[aout]',
      );
    });

    test('the input count must match the supplied labels', () {
      expect(
        () => const AmixNode(inputCount: 2).mixChain(labels: ['a0'], outLabel: 'aout'),
        throwsArgumentError,
      );
    });
  });

  group('clipAudioTrackNode', () {
    test('an included clip becomes a track node consuming its volume and fade', () {
      const policy = ClipAudio.included(volume: 0.6, fadeIn: Time.frames(15));
      final node = clipAudioTrackNode(policy, name: 'clip0.wav', fps: 30);
      expect(node, isNotNull);
      expect(node!.name, 'clip0.wav');
      expect(node.volume, 0.6);
      expect(node.fadeInSeconds, 0.5);
    });

    test('an included clip with no fade carries no fade-in', () {
      const policy = ClipAudio.included(volume: 0.6);
      final node = clipAudioTrackNode(policy, name: 'clip0.wav', fps: 30);
      expect(node!.fadeInSeconds, isNull);
    });

    test('a muted clip contributes no track node', () {
      const policy = ClipAudio.muted();
      expect(clipAudioTrackNode(policy, name: 'clip0.wav', fps: 30), isNull);
    });
  });
}
