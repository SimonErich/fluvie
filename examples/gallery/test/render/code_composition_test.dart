import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie_example/render/code_composition.dart';

Video _buildVideo() => Video(
  size: VideoSize.square,
  scenes: const [
    Scene(
      duration: Time.seconds(2),
      children: [Text('Hi')],
    ),
  ],
);

void main() {
  group('compositionFromVideo', () {
    test('derives geometry, fps, and frame count from the built Video', () {
      final entry = compositionFromVideo(_buildVideo);
      expect(entry.key, 'code');
      final video = entry.video();
      expect(video.width, 1080);
      expect(video.height, 1080);
      expect(video.fps, 30);
      expect(video.totalFrames, 60); // 2s at 30fps
      expect(collectMediaSources(video.scenes), isEmpty);
    });

    test('the entry build re-invokes the user builder (a fresh Video each frame)', () {
      var calls = 0;
      Video builder() {
        calls++;
        return _buildVideo();
      }

      final entry = compositionFromVideo(builder);
      expect(calls, 0, reason: 'the entry only holds the builder; nothing is built yet');
      // The entry hands the user builder through untouched: `renderVideo` derives
      // geometry from the Video it returns and wraps it (Directionality and all).
      expect(entry.video(), isA<Video>());
      expect(calls, 1, reason: 'entry.video calls the user builder');
      expect(entry.video(), isA<Video>());
      expect(calls, 2, reason: 'every call builds a fresh Video');
    });
  });
}
