import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/video_size.dart';

void main() {
  group('VideoSize', () {
    test('presets carry the exact §11 dimensions', () {
      expect(VideoSize.reels.width, 1080);
      expect(VideoSize.reels.height, 1920);
      expect(VideoSize.square.width, 1080);
      expect(VideoSize.square.height, 1080);
      expect(VideoSize.hd.width, 1920);
      expect(VideoSize.hd.height, 1080);
      expect(VideoSize.fourK.width, 3840);
      expect(VideoSize.fourK.height, 2160);
    });

    test('story is the identical const alias of reels (§11)', () {
      expect(identical(VideoSize.story, VideoSize.reels), isTrue);
    });

    test('equal dimensions are value-equal with matching hashCodes', () {
      // Built at runtime so const canonicalization cannot make the
      // comparison an identity check in disguise.
      expect(_runtimeSize(1080, 1920), VideoSize.reels);
      expect(_runtimeSize(1080, 1920).hashCode, VideoSize.reels.hashCode);
    });

    test('different dimensions are not equal, even transposed', () {
      expect(VideoSize.hd, isNot(VideoSize.reels));
      expect(const VideoSize(100, 200), isNot(const VideoSize(100, 201)));
    });

    test('toString names both dimensions', () {
      expect(const VideoSize(640, 480).toString(), 'VideoSize(640x480)');
    });

    test('non-positive dimensions assert', () {
      expect(() => VideoSize(0, 1080), throwsAssertionError);
      expect(() => VideoSize(1080, 0), throwsAssertionError);
      expect(() => VideoSize(-1, 1080), throwsAssertionError);
      expect(() => VideoSize(1080, -1), throwsAssertionError);
    });
  });
}

/// Constructs a [VideoSize] from runtime values, defeating const
/// canonicalization for the equality tests.
VideoSize _runtimeSize(int width, int height) => VideoSize(width, height);
