import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/audio/encoding/amix_node.dart';
import 'package:fluvie/src/audio/encoding/audio_track_node.dart';
import 'package:fluvie/src/core/quality.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_args.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_filter_graph.dart';

/// A fully-populated builder for the Phase 4 demo shape (320x240 @ 30fps).
FfmpegArgsBuilder _demoBuilder({Quality quality = Quality.high}) {
  final filters = FfmpegFilterGraph()
    ..add(FilterNode('format', args: const {'pix_fmts': 'yuv420p'}));
  return FfmpegArgsBuilder()
    ..addRawVideoInput(name: 'frames.rgba', width: 320, height: 240, fps: 30)
    ..setH264Output(name: 'out.mp4', quality: quality, fps: 30, filters: filters);
}

void main() {
  group('FfmpegArgsBuilder', () {
    test('golden full arg array for the demo config', () {
      expect(_demoBuilder().build(), [
        '-f',
        'rawvideo',
        '-pix_fmt',
        'rgba',
        '-video_size',
        '320x240',
        '-framerate',
        '30',
        '-i',
        'frames.rgba',
        '-vf',
        'format=pix_fmts=yuv420p',
        '-c:v',
        'libx264',
        '-preset',
        'medium',
        '-crf',
        '18',
        '-pix_fmt',
        'yuv420p',
        '-r',
        '30',
        '-an',
        '-fflags',
        '+bitexact',
        '-flags:v',
        '+bitexact',
        '-map_metadata',
        '-1',
        '-threads',
        '1',
        'out.mp4',
      ]);
    });

    test('rawvideo input args are exact', () {
      final args = _demoBuilder().build();
      final i = args.indexOf('-f');
      expect(args.sublist(i, i + 10), [
        '-f',
        'rawvideo',
        '-pix_fmt',
        'rgba',
        '-video_size',
        '320x240',
        '-framerate',
        '30',
        '-i',
        'frames.rgba',
      ]);
    });

    for (final (quality, crf) in const [
      (Quality.low, '28'),
      (Quality.medium, '23'),
      (Quality.high, '18'),
      (Quality.max, '14'),
    ]) {
      test('quality ${quality.name} maps to CRF $crf', () {
        final args = _demoBuilder(quality: quality).build();
        expect(args[args.indexOf('-crf') + 1], crf);
      });
    }

    test('always encodes libx264 with preset medium and yuv420p', () {
      final args = _demoBuilder().build();
      expect(args[args.indexOf('-c:v') + 1], 'libx264');
      expect(args[args.indexOf('-preset') + 1], 'medium');
      expect(args[args.indexOf('-pix_fmt', args.indexOf('-i')) + 1], 'yuv420p');
    });

    test('the bitexact quartet is always present, in order, with -threads 1', () {
      final args = _demoBuilder().build();
      final i = args.indexOf('-fflags');
      expect(i, isPositive);
      expect(args.sublist(i, i + 8), [
        '-fflags',
        '+bitexact',
        '-flags:v',
        '+bitexact',
        '-map_metadata',
        '-1',
        '-threads',
        '1',
      ]);
    });

    test('emits -an and never -y when there is no audio', () {
      final args = _demoBuilder().build();
      expect(args, contains('-an'));
      expect(args, isNot(contains('-y')));
    });

    test('omits -vf when no filter graph is given', () {
      final builder = FfmpegArgsBuilder()
        ..addRawVideoInput(name: 'frames.rgba', width: 320, height: 240, fps: 30)
        ..setH264Output(name: 'out.mp4', quality: Quality.high, fps: 30);
      expect(builder.build(), isNot(contains('-vf')));
    });

    test('the output name is the final argument', () {
      expect(_demoBuilder().build().last, 'out.mp4');
    });

    test('build is deterministic across calls', () {
      final builder = _demoBuilder();
      expect(builder.build(), builder.build());
    });

    group('name validation', () {
      test('rejects path traversal: ../evil.mp4', () {
        expect(
          () => FfmpegArgsBuilder().addRawVideoInput(
            name: '../evil.mp4',
            width: 320,
            height: 240,
            fps: 30,
          ),
          throwsArgumentError,
        );
      });

      test('rejects a name that would parse as a flag: -flag.mp4', () {
        final builder = FfmpegArgsBuilder()
          ..addRawVideoInput(name: 'frames.rgba', width: 320, height: 240, fps: 30);
        expect(
          () => builder.setH264Output(name: '-flag.mp4', quality: Quality.high, fps: 30),
          throwsArgumentError,
        );
      });

      test('rejects an absolute path output', () {
        final builder = FfmpegArgsBuilder()
          ..addRawVideoInput(name: 'frames.rgba', width: 320, height: 240, fps: 30);
        expect(
          () => builder.setH264Output(name: '/tmp/out.mp4', quality: Quality.high, fps: 30),
          throwsArgumentError,
        );
      });

      test('rejects backslash separators and empty names', () {
        final builder = FfmpegArgsBuilder();
        expect(
          () => builder.addRawVideoInput(name: r'dir\frames.rgba', width: 2, height: 2, fps: 1),
          throwsArgumentError,
        );
        expect(
          () => builder.addRawVideoInput(name: '', width: 2, height: 2, fps: 1),
          throwsArgumentError,
        );
      });

      test('rejects a lavfi graph that would parse as a flag', () {
        expect(() => FfmpegArgsBuilder().addLavfiInput('-evil'), throwsArgumentError);
        expect(() => FfmpegArgsBuilder().addLavfiInput(''), throwsArgumentError);
      });

      test('a valid lavfi graph is emitted as -f lavfi -i <graph> and builds', () {
        final args =
            (FfmpegArgsBuilder()
                  ..addLavfiInput('testsrc=duration=1:size=2x2:rate=1')
                  ..setH264Output(name: 'out.mp4', quality: Quality.low, fps: 1))
                .build();
        expect(
          args,
          containsAllInOrder(['-f', 'lavfi', '-i', 'testsrc=duration=1:size=2x2:rate=1']),
        );
        // A lavfi input alone satisfies the "at least one input" precondition.
        expect(args.last, 'out.mp4');
      });
    });

    group('audio mix path (filter_complex)', () {
      FfmpegArgsBuilder builderWith(List<AudioTrackNode> tracks, {AmixNode? amix}) {
        final filters = FfmpegFilterGraph()
          ..add(FilterNode('format', args: const {'pix_fmts': 'yuv420p'}));
        return FfmpegArgsBuilder()
          ..addRawVideoInput(name: 'frames.rgba', width: 320, height: 240, fps: 30)
          ..setH264Output(
            name: 'out.mp4',
            quality: Quality.high,
            fps: 30,
            filters: filters,
            audio: tracks,
            amix: amix ?? AmixNode(inputCount: tracks.length),
          );
      }

      test('a single track maps the audio output after 0:v:0 with -shortest', () {
        final args = builderWith([const AudioTrackNode(name: 'track0.wav')]).build();
        expect(args, isNot(contains('-an')));
        expect(args, containsAllInOrder(['-i', 'track0.wav']));
        expect(args, contains('-filter_complex'));
        final graph = args[args.indexOf('-filter_complex') + 1];
        expect(graph, contains('[1:a]asetpts=PTS-STARTPTS,volume=1[a0]'));
        expect(graph, contains('[a0]amix=inputs=1:normalize=0,volume=1[aout]'));
        final firstMap = args.indexOf('-map');
        expect(args.sublist(firstMap, firstMap + 4), ['-map', '0:v:0', '-map', '[aout]']);
        expect(args, contains('-shortest'));
      });

      test('encodes AAC at 192k for the audio stream', () {
        final args = builderWith([const AudioTrackNode(name: 'track0.wav')]).build();
        expect(args, containsAllInOrder(['-c:a', 'aac', '-b:a', '192k']));
      });

      test('multiple tracks build one amix graph mapped from [aout]', () {
        final args = builderWith([
          const AudioTrackNode(name: 'track0.wav'),
          const AudioTrackNode(name: 'track1.wav', delayMs: 1000),
        ], amix: const AmixNode(inputCount: 2)).build();
        expect(args.where((a) => a == '-i'), hasLength(3));
        final graph = args[args.indexOf('-filter_complex') + 1];
        expect(graph, contains('[1:a]asetpts=PTS-STARTPTS,volume=1[a0]'));
        expect(graph, contains('[2:a]asetpts=PTS-STARTPTS,adelay=1000|1000,volume=1[a1]'));
        expect(graph, contains('[a0][a1]amix=inputs=2:normalize=0,volume=1[aout]'));
        final firstMap = args.indexOf('-map');
        expect(args.sublist(firstMap, firstMap + 4), ['-map', '0:v:0', '-map', '[aout]']);
      });

      test('a looping track prefixes -stream_loop -1 before its -i, bounded by -shortest', () {
        final args = builderWith([const AudioTrackNode(name: 'bed.wav', loop: true)]).build();
        final input = args.indexOf('bed.wav');
        expect(args.sublist(input - 3, input + 1), ['-stream_loop', '-1', '-i', 'bed.wav']);
        // Still one extra -i beyond the video; the looped input is filtered at index 1.
        expect(args.where((a) => a == '-i'), hasLength(2));
        final graph = args[args.indexOf('-filter_complex') + 1];
        expect(graph, contains('[1:a]asetpts=PTS-STARTPTS,volume=1[a0]'));
        expect(args, contains('-shortest'));
      });

      test('a non-looping track emits no -stream_loop (the default is unchanged)', () {
        final args = builderWith([const AudioTrackNode(name: 'bed.wav')]).build();
        expect(args, isNot(contains('-stream_loop')));
      });

      test('the bitexact quartet and -threads 1 are unchanged with audio', () {
        final args = builderWith([const AudioTrackNode(name: 'track0.wav')]).build();
        final i = args.indexOf('-fflags');
        expect(args.sublist(i, i + 8), [
          '-fflags',
          '+bitexact',
          '-flags:v',
          '+bitexact',
          '-map_metadata',
          '-1',
          '-threads',
          '1',
        ]);
      });

      test('the -vf video graph survives alongside -filter_complex', () {
        final args = builderWith([const AudioTrackNode(name: 'track0.wav')]).build();
        expect(args[args.indexOf('-vf') + 1], 'format=pix_fmts=yuv420p');
      });

      test('audio track nodes with no amix throw a StateError at build', () {
        // A track contributes a filter chain, so the builder routes through
        // -filter_complex and requires an FfmpegAudioMix to combine the pads.
        final builder = FfmpegArgsBuilder()
          ..addRawVideoInput(name: 'frames.rgba', width: 320, height: 240, fps: 30)
          ..setH264Output(
            name: 'out.mp4',
            quality: Quality.high,
            fps: 30,
            audio: const [AudioTrackNode(name: 'track0.wav')],
            // amix deliberately omitted
          );
        expect(
          builder.build,
          throwsA(
            isA<StateError>().having((e) => e.message, 'message', contains('FfmpegAudioMix')),
          ),
        );
      });

      test('an injected name in a track is rejected at build', () {
        final builder = FfmpegArgsBuilder()
          ..addRawVideoInput(name: 'frames.rgba', width: 320, height: 240, fps: 30)
          ..setH264Output(
            name: 'out.mp4',
            quality: Quality.high,
            fps: 30,
            audio: const [AudioTrackNode(name: '../evil.wav')],
          );
        expect(builder.build, throwsArgumentError);
      });
    });

    test('the no-audio arg array is byte-identical to the documented baseline', () {
      // Regression pin (decision D-Mix): growing the audio path must not perturb
      // the media-less encode by a single argument.
      expect(_demoBuilder().build(), const [
        '-f',
        'rawvideo',
        '-pix_fmt',
        'rgba',
        '-video_size',
        '320x240',
        '-framerate',
        '30',
        '-i',
        'frames.rgba',
        '-vf',
        'format=pix_fmts=yuv420p',
        '-c:v',
        'libx264',
        '-preset',
        'medium',
        '-crf',
        '18',
        '-pix_fmt',
        'yuv420p',
        '-r',
        '30',
        '-an',
        '-fflags',
        '+bitexact',
        '-flags:v',
        '+bitexact',
        '-map_metadata',
        '-1',
        '-threads',
        '1',
        'out.mp4',
      ]);
    });

    group('build preconditions', () {
      test('build without an output throws StateError', () {
        final builder = FfmpegArgsBuilder()
          ..addRawVideoInput(name: 'frames.rgba', width: 320, height: 240, fps: 30);
        expect(builder.build, throwsStateError);
      });

      test('build without any input throws StateError', () {
        final builder = FfmpegArgsBuilder()
          ..setH264Output(name: 'out.mp4', quality: Quality.high, fps: 30);
        expect(builder.build, throwsStateError);
      });

      test('setting the output twice throws StateError', () {
        final builder = _demoBuilder();
        expect(
          () => builder.setH264Output(name: 'other.mp4', quality: Quality.low, fps: 30),
          throwsStateError,
        );
      });
    });
  });
}
