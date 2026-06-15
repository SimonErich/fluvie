import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/quality.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_args.dart';

import '../fakes/silent_track_node.dart' show SilentTrackNode;

void main() {
  group('SilentTrackNode', () {
    test('emits the exact lavfi anullsrc input fragment', () {
      expect(SilentTrackNode(1.6).inputArgs(), [
        '-f',
        'lavfi',
        '-t',
        '1.6',
        '-i',
        'anullsrc=r=48000:cl=stereo',
      ]);
    });

    test('maps the audio stream of its assigned input index', () {
      expect(SilentTrackNode(1).mapSpecifier(1), '1:a');
      expect(SilentTrackNode(1).mapSpecifier(2), '2:a');
    });
  });

  group('FfmpegArgsBuilder audio path', () {
    FfmpegArgsBuilder builderWith(List<SilentTrackNode> audio) => FfmpegArgsBuilder()
      ..addRawVideoInput(name: 'frames.rgba', width: 320, height: 240, fps: 30)
      ..setH264Output(name: 'out.mp4', quality: Quality.high, fps: 30, audio: audio);

    test('no nodes: -an present, no -shortest, no -map', () {
      final args = builderWith(const []).build();
      expect(args, contains('-an'));
      expect(args, isNot(contains('-shortest')));
      expect(args, isNot(contains('-map')));
    });

    test('one silent node: lavfi input present, video-then-audio maps, -shortest', () {
      final args = builderWith([SilentTrackNode(1)]).build();
      expect(args, isNot(contains('-an')));
      expect(
        args,
        containsAllInOrder(['-f', 'lavfi', '-t', '1', '-i', 'anullsrc=r=48000:cl=stereo']),
      );
      final firstMap = args.indexOf('-map');
      expect(args.sublist(firstMap, firstMap + 4), ['-map', '0:v:0', '-map', '1:a']);
      expect(args, contains('-shortest'));
    });

    test('audio inputs come after the video input, before output options', () {
      final args = builderWith([SilentTrackNode(1)]).build();
      expect(args.indexOf('anullsrc=r=48000:cl=stereo'), greaterThan(args.indexOf('frames.rgba')));
      expect(args.indexOf('anullsrc=r=48000:cl=stereo'), lessThan(args.indexOf('-c:v')));
    });

    test('two nodes: two inputs mapped at consecutive indices', () {
      final args = builderWith([SilentTrackNode(1), SilentTrackNode(2)]).build();
      expect(args.where((a) => a == 'anullsrc=r=48000:cl=stereo'), hasLength(2));
      final firstMap = args.indexOf('-map');
      expect(args.sublist(firstMap, firstMap + 6), [
        '-map',
        '0:v:0',
        '-map',
        '1:a',
        '-map',
        '2:a',
      ]);
      expect(args, contains('-shortest'));
    });
  });
}
