import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

void main() {
  group('TimeScopeData', () {
    test('a root scope carries fps, startFrame, durationFrames, and no parent', () {
      const root = TimeScopeData(fps: 30, startFrame: 0, durationFrames: 600);
      expect(root.fps, 30);
      expect(root.startFrame, 0);
      expect(root.durationFrames, 600);
      expect(root.parent, isNull);
    });

    test('child inherits fps and links back to its parent', () {
      const root = TimeScopeData(fps: 24, startFrame: 0, durationFrames: 480);
      final scene = root.child(startFrame: 120, durationFrames: 240);
      expect(scene.fps, 24);
      expect(scene.startFrame, 120);
      expect(scene.durationFrames, 240);
      expect(scene.parent, same(root));
    });

    test('endFrame is startFrame + durationFrames', () {
      const scope = TimeScopeData(fps: 30, startFrame: 90, durationFrames: 300);
      expect(scope.endFrame, 390);
    });

    test('value equality includes the parent chain', () {
      const rootA = TimeScopeData(fps: 30, startFrame: 0, durationFrames: 600);
      const rootB = TimeScopeData(fps: 30, startFrame: 0, durationFrames: 600);
      const otherRoot = TimeScopeData(fps: 30, startFrame: 0, durationFrames: 900);
      final sceneA = rootA.child(startFrame: 60, durationFrames: 300);
      final sceneB = rootB.child(startFrame: 60, durationFrames: 300);
      final sceneC = otherRoot.child(startFrame: 60, durationFrames: 300);
      expect(sceneA, equals(sceneB));
      expect(sceneA.hashCode, sceneB.hashCode);
      expect(sceneA, isNot(equals(sceneC)));
      expect(rootA, isNot(equals(otherRoot)));
    });

    test('two-level nesting: video -> scene -> element window', () {
      const video = TimeScopeData(fps: 30, startFrame: 0, durationFrames: 900);
      final scene = video.child(startFrame: 300, durationFrames: 300);
      final window = scene.child(startFrame: 330, durationFrames: 120);
      expect(window.fps, 30);
      expect(window.parent, same(scene));
      expect(window.parent?.parent, same(video));
      expect(window.endFrame, 450);
    });

    test('0.5.relative against a 300-frame scope resolves to 150', () {
      const scope = TimeScopeData(fps: 30, startFrame: 0, durationFrames: 300);
      expect(0.5.relative.resolveFrames(scope), 150);
    });

    test('toString names the numbers and nests the parent', () {
      const root = TimeScopeData(fps: 30, startFrame: 0, durationFrames: 600);
      final scene = root.child(startFrame: 60, durationFrames: 300);
      expect(root.toString(), 'TimeScopeData(fps: 30, frames: 0..600)');
      expect(scene.toString(), contains('frames: 60..360'));
      expect(scene.toString(), contains('parent: TimeScopeData(fps: 30, frames: 0..600)'));
    });
  });
}
