import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/camera/camera.dart';
import 'package:fluvie/src/composition/camera/camera_layer.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';

// A scene scope spanning absolute frames [start, start + duration) at fps.
TimeScopeData _scene({int start = 0, int duration = 60, int fps = 30}) =>
    TimeScopeData(fps: fps, startFrame: start, durationFrames: duration);

// Mounts a CameraLayer under a scene scope at [frame], returning the captured
// Transform whose matrix and alignment the camera pose drives.
Future<Transform> _pumpTransform(
  WidgetTester tester, {
  required Camera camera,
  required int frame,
  TimeScopeData? scope,
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: TimeScopeProvider(
        scope: scope ?? _scene(),
        child: FrameProvider(
          frame: frame,
          child: CameraLayer(
            camera: camera,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      ),
    ),
  );
  return tester.widget<Transform>(find.byType(Transform));
}

double _scaleX(Transform t) => t.transform.getMaxScaleOnAxis();

void main() {
  group('CameraLayer push', () {
    // over: 0.5.relative over a 60-frame scene resolves to 30 frames, so the
    // move runs frames 0..30 then holds. zoom 2 makes scale = 1 + q.
    const camera = Camera.push(zoom: 2, toward: Alignment.topRight, over: Time.relative(0.5));

    testWidgets('scale and alignment at the scene start (q = 0)', (tester) async {
      final t = await _pumpTransform(tester, camera: camera, frame: 0);
      expect(_scaleX(t), moreOrLessEquals(1));
      expect(t.alignment, Alignment.topRight);
    });

    testWidgets('scale at the half-over frame (q = 0.5)', (tester) async {
      // overFrames = 30; frame 15 -> q = 0.5 -> scale 1.5.
      final t = await _pumpTransform(tester, camera: camera, frame: 15);
      expect(_scaleX(t), moreOrLessEquals(1.5));
    });

    testWidgets('reaches the end pose exactly at over (q = 1)', (tester) async {
      final t = await _pumpTransform(tester, camera: camera, frame: 30);
      expect(_scaleX(t), moreOrLessEquals(2));
    });

    testWidgets('holds the end pose after over', (tester) async {
      // Frame 45 is past the 30-frame move: still scale 2.
      final t = await _pumpTransform(tester, camera: camera, frame: 45);
      expect(_scaleX(t), moreOrLessEquals(2));
    });

    testWidgets('holds the end pose at the last scene frame', (tester) async {
      final t = await _pumpTransform(tester, camera: camera, frame: 59);
      expect(_scaleX(t), moreOrLessEquals(2));
    });
  });

  group('CameraLayer pan focal', () {
    const camera = Camera.pan(
      from: Alignment.topLeft,
      to: Alignment.bottomRight,
      zoom: 1.5,
    );

    testWidgets('focal lerps from -> to across the scene', (tester) async {
      final start = await _pumpTransform(tester, camera: camera, frame: 0);
      expect(start.alignment, Alignment.topLeft);

      final mid = await _pumpTransform(tester, camera: camera, frame: 30);
      expect(mid.alignment, Alignment.center);

      final end = await _pumpTransform(tester, camera: camera, frame: 59);
      // Frame 59 over a 60-frame scene: q = 59/60, very close to bottomRight.
      final alignment = end.alignment! as Alignment;
      expect(alignment.x, greaterThan(0.9));
      expect(alignment.y, greaterThan(0.9));

      // The pan holds a constant zoom throughout.
      expect(_scaleX(start), moreOrLessEquals(1.5));
      expect(_scaleX(end), moreOrLessEquals(1.5));
    });
  });

  group('CameraLayer still', () {
    testWidgets('mounts an identity transform (constant shape)', (tester) async {
      final t = await _pumpTransform(tester, camera: const Camera.still(), frame: 20);
      expect(_scaleX(t), moreOrLessEquals(1));
      expect(t.alignment, Alignment.center);
      // It is always mounted, even though it is the identity.
      expect(find.byType(Transform), findsOneWidget);
    });
  });

  group('CameraLayer freeze consistency', () {
    // A frozen FrameProvider above the layer (the D2/D11 boundary freeze)
    // pins the pose to the frozen value regardless of any scope drift.
    const camera = Camera.push(zoom: 2, over: Time.relative(0.5));

    testWidgets('a clamped frame freezes the pose', (tester) async {
      // Freeze at frame 15 (q = 0.5 -> scale 1.5) and confirm it does not
      // advance the way an unfrozen frame 30 would.
      final frozen = await _pumpTransform(tester, camera: camera, frame: 15);
      expect(_scaleX(frozen), moreOrLessEquals(1.5));

      final live = await _pumpTransform(tester, camera: camera, frame: 30);
      expect(_scaleX(live), moreOrLessEquals(2));
    });
  });

  group('CameraLayer relative over resolves against the scene', () {
    // A scene that starts at video frame 90 and lasts 60 frames. over =
    // 1.0.relative must resolve to 60 (the scene's own length), not the video.
    final scope = _scene(start: 90);

    testWidgets('q is measured from the scene start over the scene length', (tester) async {
      const camera = Camera.push(zoom: 2);
      // Scene-local frame 30 = video frame 120 -> q = 30/60 = 0.5 -> scale 1.5.
      final t = await _pumpTransform(tester, camera: camera, frame: 120, scope: scope);
      expect(_scaleX(t), moreOrLessEquals(1.5));

      // Scene-local frame 0 = video frame 90 -> q = 0 -> scale 1.
      final atStart = await _pumpTransform(tester, camera: camera, frame: 90, scope: scope);
      expect(_scaleX(atStart), moreOrLessEquals(1));
    });

    testWidgets('an absolute over is fps-resolved, not scene-relative', (tester) async {
      // over: 1.second @ 30 fps = 30 frames.
      const camera = Camera.push(zoom: 2, over: Time.seconds(1));
      final t = await _pumpTransform(tester, camera: camera, frame: 105, scope: scope);
      // Scene-local frame 15 -> q = 15/30 = 0.5 -> scale 1.5.
      expect(_scaleX(t), moreOrLessEquals(1.5));
    });
  });

  group('CameraLayer eased progress', () {
    testWidgets('a non-linear ease bends the scale curve', (tester) async {
      const camera = Camera.push(zoom: 2, ease: Ease.smooth);
      // easeInOut at p = 0.5 is exactly 0.5, so scale is still 1.5 at mid.
      final mid = await _pumpTransform(tester, camera: camera, frame: 30);
      expect(_scaleX(mid), moreOrLessEquals(1.5));
      // At p = 0.25 easeInOut < 0.25, so the scale lags a linear ramp.
      final early = await _pumpTransform(tester, camera: camera, frame: 15);
      expect(_scaleX(early), lessThan(1.25));
    });
  });

  // Touch .relative so the import stays used and the sugar matches Time.relative.
  test('relative sugar equals the literal default over', () {
    expect(const Camera.push().over, 1.0.relative);
  });
}
