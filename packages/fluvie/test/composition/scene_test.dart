import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/audio/audio.dart';
import 'package:fluvie/src/composition/background/background.dart';
import 'package:fluvie/src/composition/camera/camera.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/transition.dart';
import 'package:fluvie/src/timing/video_scope.dart';

import 'fakes/fake_timeline.dart';

/// Renders [scene] on a 160×284 canvas under a video scope and returns its
/// raw pixels.
Future<Uint8List> _pixelsOf(WidgetTester tester, Scene scene) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    Center(
      child: RepaintBoundary(
        key: key,
        child: SizedBox(
          width: 160,
          height: 284,
          child: VideoScope(fps: 30, duration: 4.seconds, child: scene),
        ),
      ),
    ),
  );
  late final Uint8List bytes;
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final data = await image.toByteData();
    bytes = data!.buffer.asUint8List();
  });
  await tester.pumpWidget(const SizedBox.shrink());
  return bytes;
}

void main() {
  group('Scene', () {
    test('carries its fields verbatim', () {
      const defaults = Defaults(duration: Time.seconds(1));
      const audio = [Audio.music('song.mp3')];
      final scene = Scene(
        duration: 4.seconds,
        motionDefaults: defaults,
        audio: audio,
        children: const [Text('hi', textDirection: TextDirection.ltr)],
      );
      expect(scene.duration, 4.seconds);
      expect(scene.motionDefaults, same(defaults));
      expect(scene.audio, same(audio));
      expect(scene.children, hasLength(1));
    });

    test('audio and children default to empty lists', () {
      final scene = Scene(duration: 4.seconds);
      expect(scene.audio, isEmpty);
      expect(scene.children, isEmpty);
    });

    testWidgets('mounts its children in a centered Stack (D6)', (tester) async {
      const first = SizedBox(width: 10, height: 10);
      const second = SizedBox(width: 20, height: 20);
      await tester.pumpWidget(
        VideoScope(
          fps: 30,
          duration: 4.seconds,
          child: Scene(duration: 4.seconds, children: const [first, second]),
        ),
      );
      final stack = tester.widget<Stack>(
        find.descendant(of: find.byType(Scene), matching: find.byType(Stack)),
      );
      expect(stack.alignment, Alignment.center);
      expect(stack.children, const [first, second]);
    });

    testWidgets('a bare centered child sits at the canvas center (D6)', (tester) async {
      await tester.pumpWidget(
        VideoScope(
          fps: 30,
          duration: 4.seconds,
          child: Scene(
            duration: 4.seconds,
            children: const [SizedBox(width: 10, height: 10)],
          ),
        ),
      );
      final canvas = tester.getRect(find.byType(Scene));
      final child = tester.getRect(find.byType(SizedBox));
      expect(child.center, canvas.center);
    });

    testWidgets('throws a FluvieTimingError naming Video without an enclosing scope', (
      tester,
    ) async {
      await tester.pumpWidget(Scene(duration: 4.seconds));
      expect(
        tester.takeException(),
        isA<FluvieTimingError>().having((e) => e.message, 'message', contains('Video')),
      );
    });
  });

  group('Scene.sequence (WI-12/WI-13, D9)', () {
    test('takes its duration from the timeline schedule', () {
      final timeline = FakeTimeline(5.seconds);
      final scene = Scene.sequence(timeline: timeline);
      expect(scene.duration, 5.seconds);
    });

    test('forwards children, defaults, and audio verbatim', () {
      const defaults = Defaults(duration: Time.seconds(1));
      const audio = [Audio.music('song.mp3')];
      const child = SizedBox(width: 10, height: 10);
      final scene = Scene.sequence(
        timeline: FakeTimeline(2.seconds),
        motionDefaults: defaults,
        audio: audio,
        children: const [child],
      );
      expect(scene.children, const [child]);
      expect(scene.motionDefaults, same(defaults));
      expect(scene.audio, same(audio));
    });
  });

  group('Scene.centered (WI-13)', () {
    test('mounts exactly one Center-wrapped child', () {
      const child = SizedBox(width: 10, height: 10);
      final scene = Scene.centered(duration: 4.seconds, child: child);
      expect(scene.children, hasLength(1));
      final center = scene.children.single as Center;
      expect(center.child, same(child));
    });

    test('forwards duration, defaults, and audio verbatim', () {
      const defaults = Defaults(duration: Time.seconds(1));
      const audio = [Audio.sfx('pop.wav')];
      final scene = Scene.centered(
        duration: 4.seconds,
        motionDefaults: defaults,
        audio: audio,
        child: const SizedBox.shrink(),
      );
      expect(scene.duration, 4.seconds);
      expect(scene.motionDefaults, same(defaults));
      expect(scene.audio, same(audio));
    });

    testWidgets('the centered child sits at the canvas center', (tester) async {
      await tester.pumpWidget(
        VideoScope(
          fps: 30,
          duration: 4.seconds,
          child: Scene.centered(
            duration: 4.seconds,
            child: const SizedBox(width: 10, height: 10),
          ),
        ),
      );
      final canvas = tester.getRect(find.byType(Scene));
      final child = tester.getRect(find.byType(SizedBox));
      expect(child.center, canvas.center);
    });
  });

  group('Scene(background:) (WI-23, §16)', () {
    testWidgets('the background mounts as the first Stack child, below the content', (
      tester,
    ) async {
      final background = Background.color(const Color(0xFF112233));
      const child = SizedBox(width: 10, height: 10);
      await tester.pumpWidget(
        VideoScope(
          fps: 30,
          duration: 4.seconds,
          child: Scene(duration: 4.seconds, background: background, children: const [child]),
        ),
      );
      final stack = tester.widget<Stack>(
        find.descendant(of: find.byType(Scene), matching: find.byType(Stack)),
      );
      expect(stack.children, hasLength(2));
      expect(stack.children.first, same(background));
      expect(stack.children.last, same(child));
    });

    testWidgets('no background means the Stack holds only the children', (tester) async {
      await tester.pumpWidget(
        VideoScope(
          fps: 30,
          duration: 4.seconds,
          child: Scene(duration: 4.seconds, children: const [SizedBox(width: 10, height: 10)]),
        ),
      );
      final stack = tester.widget<Stack>(
        find.descendant(of: find.byType(Scene), matching: find.byType(Stack)),
      );
      expect(stack.children, hasLength(1));
    });

    testWidgets('the same Background paints identically as background: and as a child', (
      tester,
    ) async {
      final background = Background.gradient(const [Color(0xFFFF0000), Color(0xFF00FF00)]);
      const square = SizedBox(width: 40, height: 40, child: ColoredBox(color: Color(0xFF0000FF)));
      final asParameter = await _pixelsOf(
        tester,
        Scene(duration: 4.seconds, background: background, children: const [square]),
      );
      final asChild = await _pixelsOf(
        tester,
        Scene(duration: 4.seconds, children: [background, square]),
      );
      expect(listEquals(asParameter, asChild), isTrue);
    });

    test('Scene.sequence and Scene.centered forward the background verbatim', () {
      final background = Background.color(const Color(0xFF112233));
      final sequence = Scene.sequence(timeline: FakeTimeline(2.seconds), background: background);
      expect(sequence.background, same(background));
      final centered = Scene.centered(
        duration: 4.seconds,
        background: background,
        child: const SizedBox.shrink(),
      );
      expect(centered.background, same(background));
    });
  });

  group('Scene(enter:/exit:) precedence data (WI-10, D5)', () {
    final enter = Transition.wipe(0.4.seconds);
    final exit = Transition.crossFade(0.5.seconds);

    test('the default constructor carries enter and exit verbatim', () {
      final scene = Scene(duration: 4.seconds, enter: enter, exit: exit);
      expect(scene.enter, same(enter));
      expect(scene.exit, same(exit));
    });

    test('enter and exit default to null (no opinion)', () {
      final scene = Scene(duration: 4.seconds);
      expect(scene.enter, isNull);
      expect(scene.exit, isNull);
    });

    test('Scene.sequence forwards enter and exit', () {
      final scene = Scene.sequence(
        timeline: FakeTimeline(2.seconds),
        enter: enter,
        exit: exit,
      );
      expect(scene.enter, same(enter));
      expect(scene.exit, same(exit));
    });

    test('Scene.centered forwards enter and exit', () {
      final scene = Scene.centered(
        duration: 4.seconds,
        enter: enter,
        exit: exit,
        child: const SizedBox.shrink(),
      );
      expect(scene.enter, same(enter));
      expect(scene.exit, same(exit));
    });

    test('an explicit cut() is carried verbatim, not collapsed to null', () {
      final scene = Scene(duration: 4.seconds, enter: const Transition.cut());
      expect(scene.enter, const Transition.cut());
      expect(scene.exit, isNull);
    });
  });

  group('Scene(camera:) data (WI-18, D11)', () {
    const camera = Camera.push(zoom: 1.25);

    test('the default constructor carries the camera verbatim', () {
      final scene = Scene(duration: 4.seconds, camera: camera);
      expect(scene.camera, same(camera));
    });

    test('camera defaults to null (no move)', () {
      final scene = Scene(duration: 4.seconds);
      expect(scene.camera, isNull);
    });

    test('Scene.sequence forwards the camera', () {
      final scene = Scene.sequence(timeline: FakeTimeline(2.seconds), camera: camera);
      expect(scene.camera, same(camera));
    });

    test('Scene.centered forwards the camera', () {
      final scene = Scene.centered(
        duration: 4.seconds,
        camera: camera,
        child: const SizedBox.shrink(),
      );
      expect(scene.camera, same(camera));
    });
  });
}
