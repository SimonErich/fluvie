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
        '[1:a]asetpts=PTS-STARTPTS,adelay=1500|1500,asetpts=N/SR/TB,volume=1[a0]',
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

    test('atempo retimes the source before adelay places it', () {
      // adelay pads the head with silence. Retiming after that pad would speed
      // the silence up too, so a clip delayed 2s at 2x would open its audio at
      // 1s — a second before its picture.
      const node = AudioTrackNode(name: 't.wav', delayMs: 2000, tempo: 2);

      final chain = node.filterChain(inputIndex: 0, label: 'a0');

      expect(chain.indexOf('atempo'), lessThan(chain.indexOf('adelay')));
      expect(
        chain,
        '[0:a]asetpts=PTS-STARTPTS,atempo=2,adelay=2000|2000,asetpts=N/SR/TB,volume=1[a0]',
      );
    });

    test('an atempo chain multiplies out to the rate at every stage count', () {
      // Each stage is bounded to ffmpeg's 0.5..2.0, so the product — not any
      // single stage — has to equal the rate.
      for (final rate in <double>[0.1, 0.25, 0.3, 0.5, 1.5, 2, 2.5, 3, 4, 5, 8]) {
        final chain = AudioTrackNode(
          name: 't.wav',
          tempo: rate,
        ).filterChain(inputIndex: 0, label: 'a0');
        final stages = RegExp(
          'atempo=([0-9.]+)',
        ).allMatches(chain).map((match) => double.parse(match.group(1)!)).toList();
        expect(stages, isNotEmpty, reason: 'rate $rate must emit at least one stage');
        for (final stage in stages) {
          expect(stage, inInclusiveRange(0.5, 2.0), reason: 'rate $rate stage out of range');
        }
        final product = stages.reduce((a, b) => a * b);
        expect(product, closeTo(rate, 1e-9), reason: 'rate $rate lost its value in staging');
      }
    });

    test('a delayed fade-in ramps the audio, not the silence in front of it', () {
      // adelay pads the head with real silence and afade measures st from the
      // start of its own input, so a fade at st=0 ramps the padding and the
      // clip enters at full volume. The fade has to start where the clip does.
      const node = AudioTrackNode(name: 't.wav', delayMs: 5000, fadeInSeconds: 0.5);

      expect(
        node.filterChain(inputIndex: 0, label: 'a0'),
        contains('afade=t=in:st=5:d=0.5'),
      );
    });

    test('an undelayed fade-in still starts at zero', () {
      expect(
        const AudioTrackNode(
          name: 't.wav',
          fadeInSeconds: 0.5,
        ).filterChain(inputIndex: 0, label: 'a0'),
        contains('afade=t=in:st=0:d=0.5'),
      );
    });

    test('a rate that cannot be staged is refused, never looped over', () {
      // 0 / 0.5 is 0, so the halving loop would never converge: the chain
      // builder would spin at full CPU growing a list until the process died,
      // after the whole capture had already run. Non-finite rates diverge the
      // same way, and NaN escapes both guards to emit a literal atempo=NaN.
      for (final bad in <double>[0, -1, double.infinity, double.nan]) {
        expect(
          () => AudioTrackNode(name: 't.wav', tempo: bad).filterChain(inputIndex: 0, label: 'a0'),
          throwsA(isA<ArgumentError>()),
          reason: 'tempo $bad must fail loudly rather than hang the encoder',
        );
      }
    });

    test('rate 1 emits no atempo at all, so every existing graph is unchanged', () {
      // The default rate, spelled out: every pre-existing pinned chain in this
      // file depends on an unretimed track emitting nothing here.
      expect(
        const AudioTrackNode(name: 't.wav').filterChain(inputIndex: 0, label: 'a0'),
        isNot(contains('atempo')),
      );
    });

    test('the full chain orders atrim, asetpts, adelay, volume, fades', () {
      // The fade-in starts at 0.5s, not 0: adelay pads 500ms of silence in
      // front, and a ramp at 0 would fade that padding instead of the audio.
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
        '[3:a]atrim=start=1:end=9,asetpts=PTS-STARTPTS,adelay=500|500,asetpts=N/SR/TB,volume=0.8,'
        'afade=t=in:st=0.5:d=1,afade=t=out:st=7:d=1.5[a2]',
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
