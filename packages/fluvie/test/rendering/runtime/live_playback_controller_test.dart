import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/rendering/runtime/live_playback_controller.dart';

void main() {
  group('construction', () {
    test('starts paused at the initial frame', () {
      final controller = LivePlaybackController(fps: 30, initialFrame: 12);
      expect(controller.state, LivePlaybackState.paused);
      expect(controller.frame, 12);
      controller.dispose();
    });

    test('rejects a non-positive fps and a negative initial frame', () {
      expect(() => LivePlaybackController(fps: 0), throwsAssertionError);
      expect(() => LivePlaybackController(fps: 30, initialFrame: -1), throwsAssertionError);
      expect(() => LivePlaybackController(fps: 30, rate: 0), throwsAssertionError);
      expect(() => LivePlaybackController(fps: 30, totalFrames: 0), throwsAssertionError);
    });
  });

  group('play and tick', () {
    test('advances the frame clock by elapsed wall time × fps', () {
      final controller = LivePlaybackController(fps: 30)
        ..play()
        ..handleTick(const Duration(milliseconds: 100));
      expect(controller.frame, 3);
      controller.handleTick(const Duration(milliseconds: 500));
      expect(controller.frame, 15);
      controller.dispose();
    });

    test('a ticker restart continues from the current frame, never rewinds', () {
      // A remounted LivePlayer creates a fresh ticker whose elapsed starts
      // over at zero; the clock must carry on, not replay from frame 0.
      final controller = LivePlaybackController(fps: 30)
        ..play()
        ..handleTick(const Duration(seconds: 1));
      expect(controller.frame, 30);
      controller.handleTick(const Duration(milliseconds: 16));
      expect(controller.frame, 30);
      controller.handleTick(const Duration(milliseconds: 1016));
      expect(controller.frame, 60);
      controller.dispose();
    });

    test('plays from the current frame, not from zero', () {
      final controller = LivePlaybackController(fps: 30, initialFrame: 60)
        ..play()
        ..handleTick(const Duration(seconds: 1));
      expect(controller.frame, 90);
      controller.dispose();
    });

    test('notifies frame listeners through the frames listenable', () {
      final controller = LivePlaybackController(fps: 30)..play();
      final seen = <int>[];
      controller.frames.addListener(() => seen.add(controller.frame));
      controller
        ..handleTick(const Duration(milliseconds: 100))
        ..handleTick(const Duration(milliseconds: 200));
      expect(seen, [3, 6]);
      controller.dispose();
    });

    test('play at the end of a bounded clock is a no-op', () {
      final controller = LivePlaybackController(fps: 30, totalFrames: 10, initialFrame: 9)..play();
      expect(controller.state, LivePlaybackState.paused);
      controller.dispose();
    });

    test('a bounded clock clamps at its last frame and pauses', () {
      final controller = LivePlaybackController(fps: 30, totalFrames: 30)
        ..play()
        ..handleTick(const Duration(seconds: 5));
      expect(controller.frame, 29);
      expect(controller.state, LivePlaybackState.paused);
      controller.dispose();
    });
  });

  group('pause, seek, hold', () {
    test('pause freezes the frame; later ticks are ignored', () {
      final controller = LivePlaybackController(fps: 30)
        ..play()
        ..handleTick(const Duration(milliseconds: 100))
        ..pause()
        ..handleTick(const Duration(milliseconds: 900));
      expect(controller.frame, 3);
      expect(controller.state, LivePlaybackState.paused);
      controller.dispose();
    });

    test('seek lands exactly while paused', () {
      final controller = LivePlaybackController(fps: 30)..seek(42);
      expect(controller.frame, 42);
      expect(controller.state, LivePlaybackState.paused);
      controller.dispose();
    });

    test('seek rebases a playing clock instead of jumping back', () {
      final controller = LivePlaybackController(fps: 30)
        ..play()
        ..handleTick(const Duration(seconds: 1))
        ..seek(100);
      expect(controller.frame, 100);
      // One second later the clock continues from the seek target.
      controller.handleTick(const Duration(seconds: 2));
      expect(controller.frame, 130);
      expect(controller.state, LivePlaybackState.playing);
      controller.dispose();
    });

    test('hold lands exactly and pauses', () {
      final controller = LivePlaybackController(fps: 30)
        ..play()
        ..handleTick(const Duration(seconds: 1))
        ..hold(7);
      expect(controller.frame, 7);
      expect(controller.state, LivePlaybackState.paused);
      controller.handleTick(const Duration(seconds: 2));
      expect(controller.frame, 7);
      controller.dispose();
    });

    test('seek rejects a negative frame', () {
      final controller = LivePlaybackController(fps: 30);
      expect(() => controller.seek(-1), throwsAssertionError);
      controller.dispose();
    });
  });

  group('rate', () {
    test('a doubled rate advances twice as many frames', () {
      final controller = LivePlaybackController(fps: 30, rate: 2)
        ..play()
        ..handleTick(const Duration(seconds: 1));
      expect(controller.frame, 60);
      controller.dispose();
    });

    test('changing the rate mid-play rebases without a jump', () {
      final controller = LivePlaybackController(fps: 30)
        ..play()
        ..handleTick(const Duration(seconds: 1));
      expect(controller.frame, 30);
      controller.rate = 2;
      expect(controller.frame, 30);
      controller.handleTick(const Duration(seconds: 2));
      expect(controller.frame, 90);
      controller.dispose();
    });

    test('rejects a non-positive rate', () {
      final controller = LivePlaybackController(fps: 30);
      expect(() => controller.rate = 0, throwsAssertionError);
      controller.dispose();
    });
  });

  group('playRange', () {
    test('plays the segment and stops exactly on the end frame', () async {
      final controller = LivePlaybackController(fps: 30);
      final done = controller.playRange(10, 40);
      expect(controller.frame, 10);
      expect(controller.state, LivePlaybackState.playing);
      controller.handleTick(const Duration(milliseconds: 500));
      expect(controller.frame, 25);
      controller.handleTick(const Duration(seconds: 5));
      expect(controller.frame, 40);
      expect(controller.state, LivePlaybackState.paused);
      await expectLater(done, completes);
      controller.dispose();
    });

    test('an interrupted range completes its future and holds the interruption', () async {
      final controller = LivePlaybackController(fps: 30);
      final done = controller.playRange(0, 300);
      controller
        ..handleTick(const Duration(milliseconds: 100))
        ..hold(3);
      await expectLater(done, completes);
      expect(controller.frame, 3);
      expect(controller.state, LivePlaybackState.paused);
      controller.dispose();
    });

    test('an empty range holds its frame immediately', () async {
      final controller = LivePlaybackController(fps: 30);
      await controller.playRange(5, 5);
      expect(controller.frame, 5);
      expect(controller.state, LivePlaybackState.paused);
      controller.dispose();
    });

    test('rejects an inverted range', () {
      final controller = LivePlaybackController(fps: 30);
      expect(() => controller.playRange(10, 9), throwsAssertionError);
      controller.dispose();
    });

    test('a new range supersedes the pending one and completes it', () async {
      final controller = LivePlaybackController(fps: 30);
      final first = controller.playRange(0, 300);
      final second = controller.playRange(50, 60);
      await expectLater(first, completes);
      controller.handleTick(const Duration(seconds: 1));
      expect(controller.frame, 60);
      expect(controller.state, LivePlaybackState.paused);
      await expectLater(second, completes);
      controller.dispose();
    });
  });

  group('state notifications', () {
    test('play, pause, and rate changes notify controller listeners', () {
      final controller = LivePlaybackController(fps: 30);
      var notified = 0;
      controller
        ..addListener(() => notified++)
        ..play()
        ..pause()
        ..rate = 2;
      expect(notified, 3);
      controller.dispose();
    });

    test('dispose completes a pending range future', () async {
      final controller = LivePlaybackController(fps: 30);
      final done = controller.playRange(0, 300);
      controller.dispose();
      await expectLater(done, completes);
    });
  });
}
