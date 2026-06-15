import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/timing/placement/window_resolver.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

void main() {
  // A 10s scene @30fps starting 5s into a 20s video: frames 150..450.
  const video = TimeScopeData(fps: 30, startFrame: 0, durationFrames: 600);
  final scene = video.child(startFrame: 150, durationFrames: 300);

  group('resolveElementWindow', () {
    test('no window means the whole scene (API_SPEC §27.3)', () {
      expect(resolveElementWindow(null, scene), (start: 150, end: 450));
    });

    test('explicit seconds are scene-relative, offset by the scene start', () {
      final window = 1.seconds.to(3.seconds);
      expect(resolveElementWindow(window, scene), (start: 180, end: 240));
    });

    test('relative endpoints measure the scene', () {
      final window = 0.25.relative.to(0.75.relative);
      expect(resolveElementWindow(window, scene), (start: 225, end: 375));
    });

    test('a window overhanging the scene clamps to the scene end', () {
      final window = 8.seconds.to(12.seconds);
      expect(resolveElementWindow(window, scene), (start: 390, end: 450));
    });

    test('a window fully after the scene collapses to zero length at the scene end', () {
      final window = 12.seconds.to(14.seconds);
      expect(resolveElementWindow(window, scene), (start: 450, end: 450));
    });

    test('an inverted window surfaces the TimeRange ArgumentError', () {
      final window = 8.seconds.to(3.seconds);
      expect(() => resolveElementWindow(window, scene), throwsArgumentError);
    });
  });

  group('elementScopeFor', () {
    test('no window: the scene itself is the nearest scope', () {
      expect(elementScopeFor(null, scene), same(scene));
    });

    test('a window becomes a child scope at absolute frames', () {
      final scope = elementScopeFor(2.seconds.to(6.seconds), scene);
      expect(scope.fps, 30);
      expect(scope.startFrame, 210);
      expect(scope.durationFrames, 120);
      expect(scope.parent, same(scene));
    });

    test('0.5.relative inside a 4s window of a 10s scene @30fps is 60', () {
      final scope = elementScopeFor(2.seconds.to(6.seconds), scene);
      expect(0.5.relative.resolveFrames(scope), 60);
    });
  });
}
