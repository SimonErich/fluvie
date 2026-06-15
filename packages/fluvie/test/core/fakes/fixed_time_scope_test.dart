import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/time_scope.dart';

import 'fixed_time_scope.dart';

void main() {
  group('FixedTimeScope', () {
    test('defaults to startFrame 0 and no parent', () {
      const scope = FixedTimeScope(fps: 30, durationFrames: 300);
      expect(scope.startFrame, 0);
      expect(scope.parent, isNull);
    });

    test('reports an explicit startFrame and parent', () {
      const root = FixedTimeScope(fps: 30, durationFrames: 600);
      const nested = FixedTimeScope(fps: 30, durationFrames: 300, startFrame: 90, parent: root);
      expect(nested.startFrame, 90);
      expect(nested.parent, same(root));
    });

    test('resolveFrames ignores startFrame: only fps and duration matter', () {
      const atZero = FixedTimeScope(fps: 30, durationFrames: 300);
      const shifted = FixedTimeScope(fps: 30, durationFrames: 300, startFrame: 90);
      expect(2.seconds.resolveFrames(shifted), 2.seconds.resolveFrames(atZero));
      expect(0.5.relative.resolveFrames(shifted), 150);
    });

    test('satisfies the core TimeScope contract', () {
      const TimeScope scope = FixedTimeScope(fps: 24, durationFrames: 48);
      expect(scope.fps, 24);
      expect(scope.durationFrames, 48);
      expect(scope.startFrame, 0);
      expect(scope.parent, isNull);
    });
  });
}
