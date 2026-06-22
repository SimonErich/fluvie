import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
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
      expect(entry.width, 1080);
      expect(entry.height, 1080);
      expect(entry.fps, 30);
      expect(entry.frameCount, 60); // 2s at 30fps
      expect(entry.mediaSources, isEmpty);
    });

    test('the entry build re-invokes the user builder (a fresh Video each frame)', () {
      var calls = 0;
      Video builder() {
        calls++;
        return _buildVideo();
      }

      final entry = compositionFromVideo(builder);
      expect(calls, 1, reason: 'one build to read geometry');
      expect(entry.build(), isA<Widget>());
      expect(calls, 2, reason: 'entry.build calls the user builder again');
    });
  });
}
