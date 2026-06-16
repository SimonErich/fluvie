import 'package:fluvie_cli/src/render_progress.dart';
import 'package:test/test.dart';

void main() {
  group('parseRenderProgress', () {
    test('parses a complete "<completed>/<total>" line', () {
      expect(parseRenderProgress('12/48'), const RenderProgress(completed: 12, total: 48));
    });

    test('tolerates surrounding whitespace and a trailing newline', () {
      expect(parseRenderProgress('  3/30\n'), const RenderProgress(completed: 3, total: 30));
    });

    test('returns null for an empty or half-written file', () {
      expect(parseRenderProgress(''), isNull);
      expect(parseRenderProgress('7'), isNull);
      expect(parseRenderProgress('7/'), isNull);
      expect(parseRenderProgress('/30'), isNull);
      expect(parseRenderProgress('a/b'), isNull);
      expect(parseRenderProgress('1/2/3'), isNull);
    });
  });

  group('RenderProgress', () {
    test('fraction is completed/total, clamped, and 0 before total is known', () {
      expect(const RenderProgress(completed: 24, total: 48).fraction, 0.5);
      expect(const RenderProgress(completed: 0, total: 0).fraction, 0);
      expect(const RenderProgress(completed: 60, total: 48).fraction, 1.0);
    });

    test('isComplete once every frame is captured', () {
      expect(const RenderProgress(completed: 48, total: 48).isComplete, isTrue);
      expect(const RenderProgress(completed: 47, total: 48).isComplete, isFalse);
      expect(const RenderProgress(completed: 0, total: 0).isComplete, isFalse);
    });

    test('value equality, hashCode and toString', () {
      const a = RenderProgress(completed: 1, total: 2);
      const b = RenderProgress(completed: 1, total: 2);
      const c = RenderProgress(completed: 2, total: 2);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(a.toString(), 'RenderProgress(1/2)');
    });
  });
}
