import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show LivePlaybackController;
import 'package:fluvie_editor/fluvie_editor.dart' show FrameRange, SlideTransport;

/// Drives [transport]'s clock the way a `LivePlayer` ticker would: elapsed
/// durations counted from the start of the current run (the ticker restarts
/// whenever a run begins, which is the rebase contract the controller
/// resolves frames against).
void tick(SlideTransport transport, Duration elapsed) => transport.controller.handleTick(elapsed);

void main() {
  group('construction', () {
    test('starts paused at the initial frame', () {
      final transport = SlideTransport(fps: 30, length: 120, initialFrame: 18);
      addTearDown(transport.dispose);
      expect(transport.isPlaying, isFalse);
      expect(transport.frame, 18);
      expect(transport.length, 120);
      expect(transport.loop, isNull);
    });

    test('clamps the initial frame to the slide', () {
      final transport = SlideTransport(fps: 30, length: 100, initialFrame: 500);
      addTearDown(transport.dispose);
      expect(transport.frame, 100);
    });

    test('exposes the frame clock as a listenable', () {
      final transport = SlideTransport(fps: 30, length: 100);
      addTearDown(transport.dispose);
      final seen = <int>[];
      transport.frames.addListener(() => seen.add(transport.frame));
      transport.seek(40);
      expect(seen, [40]);
      expect(transport.frames.value, 40);
    });

    test('hands the canvas the controller it plays through', () {
      final transport = SlideTransport(fps: 30, length: 100, initialFrame: 7);
      addTearDown(transport.dispose);
      expect(transport.controller, isA<LivePlaybackController>());
      expect(transport.controller.frame, 7);
      expect(transport.controller.fps, 30);
    });
  });

  group('seek', () {
    test('lands exactly on the frame and freezes there', () {
      final transport = SlideTransport(fps: 30, length: 100)..play();
      addTearDown(transport.dispose);
      expect(transport.isPlaying, isTrue);
      transport.seek(42);
      expect(transport.frame, 42);
      expect(transport.isPlaying, isFalse);
    });

    test('clamps to the slide', () {
      final transport = SlideTransport(fps: 30, length: 100);
      addTearDown(transport.dispose);
      transport.seek(500);
      expect(transport.frame, 100);
      transport.seek(-3);
      expect(transport.frame, 0);
    });
  });

  group('play, pause, toggle', () {
    test('plays from the playhead and stops exactly on the slide end', () {
      final transport = SlideTransport(fps: 30, length: 30)..play();
      addTearDown(transport.dispose);
      expect(transport.isPlaying, isTrue);
      tick(transport, const Duration(milliseconds: 500));
      expect(transport.frame, 15);
      tick(transport, const Duration(seconds: 5));
      expect(transport.frame, 30);
      expect(transport.isPlaying, isFalse);
    });

    test('play at the end restarts from frame zero', () {
      final transport = SlideTransport(fps: 30, length: 30, initialFrame: 30)..play();
      addTearDown(transport.dispose);
      expect(transport.frame, 0);
      expect(transport.isPlaying, isTrue);
    });

    test('play while playing is a no-op', () {
      final transport = SlideTransport(fps: 30, length: 100)..play();
      addTearDown(transport.dispose);
      tick(transport, const Duration(milliseconds: 500));
      transport.play();
      expect(transport.frame, 15);
      expect(transport.isPlaying, isTrue);
    });

    test('pause freezes the current frame', () {
      final transport = SlideTransport(fps: 30, length: 100)..play();
      addTearDown(transport.dispose);
      tick(transport, const Duration(milliseconds: 500));
      transport.pause();
      expect(transport.frame, 15);
      expect(transport.isPlaying, isFalse);
    });

    test('toggle flips between playing and paused', () {
      final transport = SlideTransport(fps: 30, length: 100)..toggle();
      addTearDown(transport.dispose);
      expect(transport.isPlaying, isTrue);
      transport.toggle();
      expect(transport.isPlaying, isFalse);
    });

    test('playback changes notify the transport listeners', () {
      final transport = SlideTransport(fps: 30, length: 100);
      addTearDown(transport.dispose);
      var notified = 0;
      transport
        ..addListener(() => notified++)
        ..play();
      expect(notified, greaterThan(0));
      final before = notified;
      transport.pause();
      expect(notified, greaterThan(before));
    });
  });

  group('playFrom', () {
    test('seeks and plays from there', () {
      final transport = SlideTransport(fps: 30, length: 100)..playFrom(60);
      addTearDown(transport.dispose);
      expect(transport.isPlaying, isTrue);
      expect(transport.frame, 60);
      tick(transport, const Duration(milliseconds: 500));
      expect(transport.frame, 75);
    });
  });

  group('playTo', () {
    test('plays to the target, pauses exactly there, and completes', () async {
      final transport = SlideTransport(fps: 30, length: 100, initialFrame: 5);
      addTearDown(transport.dispose);
      final done = transport.playTo(20);
      expect(transport.isPlaying, isTrue);
      tick(transport, const Duration(seconds: 1));
      expect(transport.frame, 20);
      expect(transport.isPlaying, isFalse);
      await done;
    });

    test('a target at or before the playhead just lands there', () async {
      final transport = SlideTransport(fps: 30, length: 100, initialFrame: 20);
      addTearDown(transport.dispose);
      await transport.playTo(10);
      expect(transport.frame, 10);
      expect(transport.isPlaying, isFalse);
    });

    test('clamps the target to the slide', () async {
      final transport = SlideTransport(fps: 30, length: 30);
      addTearDown(transport.dispose);
      final done = transport.playTo(500);
      tick(transport, const Duration(seconds: 5));
      expect(transport.frame, 30);
      await done;
    });

    test('never wraps into the loop', () async {
      final transport = SlideTransport(fps: 30, length: 100)
        ..setLoop(const FrameRange(10, 20))
        ..seek(0);
      addTearDown(transport.dispose);
      final done = transport.playTo(20);
      tick(transport, const Duration(seconds: 1));
      await done;
      await Future<void>.delayed(Duration.zero);
      expect(transport.frame, 20);
      expect(transport.isPlaying, isFalse);
    });
  });

  group('loop', () {
    test('setLoop stores the range and clamps it to the slide', () {
      final transport = SlideTransport(fps: 30, length: 50);
      addTearDown(transport.dispose);
      transport.setLoop(const FrameRange(10, 20));
      expect(transport.loop, const FrameRange(10, 20));
      transport.setLoop(const FrameRange(30, 90));
      expect(transport.loop, const FrameRange(30, 50));
      transport.setLoop(const FrameRange(90, 95));
      expect(transport.loop, isNull);
    });

    test('play inside the range runs to its end and wraps to its start', () async {
      final transport = SlideTransport(fps: 30, length: 100, initialFrame: 10)
        ..setLoop(const FrameRange(10, 20))
        ..play();
      addTearDown(transport.dispose);
      tick(transport, const Duration(milliseconds: 334));
      await Future<void>.delayed(Duration.zero);
      expect(transport.frame, 10);
      expect(transport.isPlaying, isTrue);
      tick(transport, const Duration(milliseconds: 100));
      expect(transport.frame, 13);
    });

    test('play outside the range snaps to its start', () {
      final transport = SlideTransport(fps: 30, length: 100)
        ..setLoop(const FrameRange(40, 60))
        ..play();
      addTearDown(transport.dispose);
      expect(transport.frame, 40);
      expect(transport.isPlaying, isTrue);
    });

    test('pause leaves the loop armed', () async {
      final transport = SlideTransport(fps: 30, length: 100, initialFrame: 10)
        ..setLoop(const FrameRange(10, 20))
        ..play();
      addTearDown(transport.dispose);
      tick(transport, const Duration(milliseconds: 100));
      transport.pause();
      expect(transport.frame, 13);
      expect(transport.loop, const FrameRange(10, 20));
      transport.play();
      tick(transport, const Duration(milliseconds: 234));
      await Future<void>.delayed(Duration.zero);
      expect(transport.frame, 10);
      expect(transport.isPlaying, isTrue);
    });

    test('a scrub keeps the loop for the next play', () {
      final transport = SlideTransport(fps: 30, length: 100)
        ..setLoop(const FrameRange(10, 20))
        ..play()
        ..seek(80);
      addTearDown(transport.dispose);
      expect(transport.isPlaying, isFalse);
      expect(transport.loop, const FrameRange(10, 20));
      transport.play();
      expect(transport.frame, 10);
    });

    test('clearing the loop mid-play keeps playing to the slide end', () async {
      final transport = SlideTransport(fps: 30, length: 40, initialFrame: 10)
        ..setLoop(const FrameRange(10, 20))
        ..play()
        ..setLoop(null);
      addTearDown(transport.dispose);
      expect(transport.loop, isNull);
      tick(transport, const Duration(seconds: 2));
      await Future<void>.delayed(Duration.zero);
      expect(transport.frame, 40);
      expect(transport.isPlaying, isFalse);
    });

    test('setting the loop mid-play confines playback to it', () async {
      final transport = SlideTransport(fps: 30, length: 100)..play();
      addTearDown(transport.dispose);
      tick(transport, const Duration(milliseconds: 100));
      transport.setLoop(const FrameRange(50, 60));
      expect(transport.frame, 50);
      expect(transport.isPlaying, isTrue);
      tick(transport, const Duration(milliseconds: 334));
      await Future<void>.delayed(Duration.zero);
      expect(transport.frame, 50);
      expect(transport.isPlaying, isTrue);
    });
  });

  group('length', () {
    test('shrinking re-clamps a paused playhead beyond the end', () {
      final transport = SlideTransport(fps: 30, length: 100, initialFrame: 80)..length = 50;
      addTearDown(transport.dispose);
      expect(transport.frame, 50);
      expect(transport.length, 50);
    });

    test('shrinking clamps or drops the loop', () {
      final transport = SlideTransport(fps: 30, length: 100)..setLoop(const FrameRange(40, 90));
      addTearDown(transport.dispose);
      transport.length = 60;
      expect(transport.loop, const FrameRange(40, 60));
      transport.length = 30;
      expect(transport.loop, isNull);
    });

    test('shrinking mid-play re-bounds the run', () {
      final transport = SlideTransport(fps: 30, length: 100)..play();
      addTearDown(transport.dispose);
      tick(transport, const Duration(seconds: 1));
      expect(transport.frame, 30);
      transport.length = 40;
      expect(transport.isPlaying, isTrue);
      tick(transport, const Duration(seconds: 1));
      expect(transport.frame, 40);
      expect(transport.isPlaying, isFalse);
    });

    test('shrinking mid-loop keeps the run confined to the loop', () async {
      final transport = SlideTransport(fps: 30, length: 100, initialFrame: 12)
        ..setLoop(const FrameRange(10, 20))
        ..play()
        ..length = 50;
      addTearDown(transport.dispose);
      expect(transport.isPlaying, isTrue);
      expect(transport.loop, const FrameRange(10, 20));
      tick(transport, const Duration(seconds: 1));
      await Future<void>.delayed(Duration.zero);
      expect(transport.frame, 10);
      expect(transport.isPlaying, isTrue);
    });

    test('growing lets the next play run further', () {
      final transport = SlideTransport(fps: 30, length: 30, initialFrame: 30)..length = 60;
      addTearDown(transport.dispose);
      expect(transport.frame, 30);
      transport.play();
      tick(transport, const Duration(seconds: 5));
      expect(transport.frame, 60);
    });
  });

  group('dispose', () {
    test('completes a pending playTo and settles quietly', () async {
      final transport = SlideTransport(fps: 30, length: 100);
      final done = transport.playTo(50);
      transport.dispose();
      await done;
    });

    test('a looping run never wraps after dispose', () async {
      final transport = SlideTransport(fps: 30, length: 100, initialFrame: 10)
        ..setLoop(const FrameRange(10, 20))
        ..play();
      tick(transport, const Duration(seconds: 1));
      transport.dispose();
      await Future<void>.delayed(Duration.zero);
    });
  });
}
