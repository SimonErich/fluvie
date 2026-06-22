import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/render_phase.dart';
import 'package:fluvie/src/rendering/render_progress.dart';

void main() {
  group('RenderProgress', () {
    test('carries the phase, frame counts, and key', () {
      const progress = RenderProgress(
        RenderPhase.capturing,
        completedFrames: 3,
        totalFrames: 10,
        compositionKey: 'k',
      );
      expect(progress.phase, RenderPhase.capturing);
      expect(progress.completedFrames, 3);
      expect(progress.totalFrames, 10);
      expect(progress.compositionKey, 'k');
      expect(progress.toString(), contains('capturing'));
      expect(progress.toString(), contains('3/10'));
      expect(progress.toString(), contains('key: k'));
    });

    test('toString degrades gracefully without frames or key', () {
      const progress = RenderProgress(RenderPhase.encoding);
      expect(progress.toString(), contains('encoding'));
      expect(progress.toString(), contains('-/-'));
    });
  });
}
