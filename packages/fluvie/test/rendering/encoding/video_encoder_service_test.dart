import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/audio/encoding/audio_mix_plan.dart';
import 'package:fluvie/src/audio/encoding/audio_track_node.dart';
import 'package:fluvie/src/core/errors/fluvie_encode_exception.dart';
import 'package:fluvie/src/core/export.dart';
import 'package:fluvie/src/core/quality.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_provider.dart';
import 'package:fluvie/src/rendering/encoding/video_encoder_service.dart';
import 'package:fluvie/src/rendering/render_config.dart';
import 'package:mocktail/mocktail.dart';

import '../fakes/silent_track_node.dart';

class _MockFfmpegProvider extends Mock implements FfmpegProvider {}

void main() {
  const service = VideoEncoderService();
  RenderConfig demo() => RenderConfig(width: 320, height: 240, frameCount: 48);

  group('VideoEncoderService.planEncodeArgs', () {
    test('plans the golden argument array for the demo config', () {
      expect(service.planEncodeArgs(demo()), const [
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

    test('is deterministic across calls', () {
      expect(service.planEncodeArgs(demo()), service.planEncodeArgs(demo()));
    });

    test('maps quality through to the CRF level', () {
      final args = service.planEncodeArgs(demo().copyWith(quality: Quality.low));
      final crf = args[args.indexOf('-crf') + 1];
      expect(crf, '28');
    });

    test('a SilentTrackNode adds the lavfi input, the maps and -shortest', () {
      final args = service.planEncodeArgs(demo(), audio: [SilentTrackNode(1.6)]);

      expect(args, containsAllInOrder(<String>['-f', 'lavfi', '-t', '1.6', '-i']));
      expect(args, contains('anullsrc=r=48000:cl=stereo'));
      expect(args, containsAllInOrder(<String>['-map', '0:v:0', '-map', '1:a', '-shortest']));
      expect(args, isNot(contains('-an')));
    });

    test('an audio mix plan routes tracks through filter_complex and AAC', () {
      final plan = buildAudioMixPlan(const [AudioTrackNode(name: 'track0.wav')]);
      final args = service.planEncodeArgs(demo(), audio: plan.tracks, amix: plan.amix);

      expect(args, containsAllInOrder(<String>['-i', 'track0.wav']));
      expect(args, contains('-filter_complex'));
      expect(args, containsAllInOrder(<String>['-map', '0:v:0', '-map', '[aout]']));
      expect(args, containsAllInOrder(<String>['-c:a', 'aac', '-b:a', '192k', '-shortest']));
      expect(args, isNot(contains('-an')));
    });

    test('an empty mix plan leaves the no-audio path byte-identical', () {
      const empty = AudioMixPlan(tracks: [], amix: null);
      expect(
        service.planEncodeArgs(demo(), audio: empty.tracks, amix: empty.amix),
        service.planEncodeArgs(demo()),
      );
    });
  });

  group('VideoEncoderService export dispatch', () {
    test('Export.mp4() is byte-identical to the no-export mp4 plan', () {
      expect(
        service.planEncodeArgs(demo(), export: const Export.mp4()),
        service.planEncodeArgs(demo()),
      );
    });

    test('Export.gif() emits the palette filter_complex and out.gif', () {
      final args = service.planEncodeArgs(demo(), export: const Export.gif(fps: 12));
      expect(args, contains('-filter_complex'));
      expect(args[args.indexOf('-filter_complex') + 1], startsWith('fps=12,'));
      expect(args, contains('-an'));
      expect(args, isNot(contains('libx264')));
      expect(args.last, 'out.gif');
    });

    test('Export.imageSequence() emits image2 png and the %0Nd pattern name', () {
      final args = service.planEncodeArgs(demo(), export: const Export.imageSequence());
      expect(args, containsAllInOrder(<String>['-c:v', 'png', '-f', 'image2']));
      expect(args.last, 'frame_%06d.png');
    });

    test('Export.transparent() emits VP9/yuva420p and out.webm', () {
      final args = service.planEncodeArgs(demo(), export: const Export.transparent());
      expect(args, containsAllInOrder(<String>['-c:v', 'libvpx-vp9', '-pix_fmt', 'yuva420p']));
      expect(args, isNot(contains('yuv420p')));
      expect(args.last, 'out.webm');
    });

    test('every export mode keeps the bitexact quartet and -threads 1', () {
      for (final export in const [
        Export.mp4(),
        Export.gif(),
        Export.imageSequence(),
        Export.transparent(),
      ]) {
        final args = service.planEncodeArgs(demo(), export: export);
        expect(args, containsAllInOrder(<String>['-fflags', '+bitexact', '-threads', '1']));
        expect(args, isNot(contains('-y')));
      }
    });

    test('Export.mp4(quality) overrides the config CRF', () {
      final args = service.planEncodeArgs(
        demo().copyWith(quality: Quality.high),
        export: const Export.mp4(quality: Quality.low),
      );
      expect(args[args.indexOf('-crf') + 1], '28');
    });

    test('planPosterArgs extracts one frame to poster.png', () {
      final args = service.planPosterArgs(demo(), posterFrame: 9);
      expect(args, containsAllInOrder(<String>['-vf', r'select=eq(n\,9)', '-vframes', '1']));
      expect(args, contains('-an'));
      expect(args, containsAllInOrder(<String>['-fflags', '+bitexact', '-threads', '1']));
      expect(args.last, 'poster.png');
      expect(args.last, VideoEncoderService.posterFileName);
    });

    test('planPosterArgs reads the same frames file at the config size', () {
      final args = service.planPosterArgs(demo(), posterFrame: 0);
      expect(args, containsAllInOrder(<String>['-i', 'frames.rgba']));
      expect(args, contains('320x240'));
    });
  });

  group('VideoEncoderService.encode', () {
    test('forwards the exact plan and sandbox to the provider', () async {
      final provider = _MockFfmpegProvider();
      final sandbox = Directory('/tmp/fluvie_encoder_sandbox');
      when(
        () => provider.encode(
          args: any(named: 'args'),
          sandbox: any(named: 'sandbox'),
        ),
      ).thenAnswer((_) async {});

      await service.encode(config: demo(), sandbox: sandbox, provider: provider);

      verify(
        () => provider.encode(args: service.planEncodeArgs(demo()), sandbox: sandbox),
      ).called(1);
    });

    test('forwards an amix plan so a real audio track encodes', () async {
      final provider = _MockFfmpegProvider();
      final sandbox = Directory('/tmp/fluvie_encoder_sandbox');
      when(
        () => provider.encode(
          args: any(named: 'args'),
          sandbox: any(named: 'sandbox'),
        ),
      ).thenAnswer((_) async {});
      final plan = buildAudioMixPlan(const [AudioTrackNode(name: 'track0.wav')]);

      await service.encode(
        config: demo(),
        sandbox: sandbox,
        provider: provider,
        audio: plan.tracks,
        amix: plan.amix,
      );

      final captured =
          verify(
                () => provider.encode(
                  args: captureAny(named: 'args'),
                  sandbox: sandbox,
                ),
              ).captured.single
              as List<String>;
      expect(captured, contains('-filter_complex'));
      expect(captured, containsAllInOrder(<String>['-map', '0:v:0', '-map', '[aout]']));
      expect(captured, isNot(contains('-an')));
    });

    test('a provider failure propagates typed', () async {
      final provider = _MockFfmpegProvider();
      when(
        () => provider.encode(
          args: any(named: 'args'),
          sandbox: any(named: 'sandbox'),
        ),
      ).thenThrow(FluvieEncodeException('boom', exitCode: 1));

      await expectLater(
        () => service.encode(
          config: demo(),
          sandbox: Directory('/tmp/fluvie_encoder_sandbox'),
          provider: provider,
        ),
        throwsA(isA<FluvieEncodeException>()),
      );
    });
  });

  setUpAll(() {
    registerFallbackValue(<String>[]);
    registerFallbackValue(Directory('/tmp'));
  });
}
