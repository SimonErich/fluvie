import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/stagger/stagger_offsets.dart';
import 'package:fluvie/src/core/stagger.dart';
import 'package:fluvie/src/core/stagger_origin.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

const _scope = TimeScopeData(fps: 30, startFrame: 0, durationFrames: 60);

List<int> _offsets(Stagger stagger, int childCount, {TimeScopeData scope = _scope}) =>
    staggerOffsetFrames(stagger: stagger, childCount: childCount, scope: scope);

void main() {
  group('staggerOffsetFrames — Stagger.each', () {
    test('resolves the gap ONCE and multiplies: 0.08 s at 30 fps gives [0, 2, 4]', () {
      // 0.08 s resolves to round(2.4) = 2 frames exactly once; resolving
      // i·gap per child would round to [0, 2, 5]. The pinned D19 rule is
      // resolve-gap-once-multiply, so child i sits at i·2 frames.
      expect(_offsets(Stagger.each(0.08.seconds), 3), [0, 2, 4]);
    });

    test('a frame-exact gap multiplies without any rounding', () {
      expect(_offsets(const Stagger.each(Time.frames(6)), 4), [0, 6, 12, 18]);
    });

    test('a single child gets the lone zero offset', () {
      expect(_offsets(Stagger.each(0.08.seconds), 1), [0]);
    });
  });

  group('staggerOffsetFrames — Stagger.evenly', () {
    test('five children over 60 frames land on [0, 15, 30, 45, 60]', () {
      expect(_offsets(const Stagger.evenly(over: Time.frames(60)), 5), [0, 15, 30, 45, 60]);
    });

    test('rounding happens per child on i·over/(n−1): four over 10 frames', () {
      // 0, 10/3 = 3.33…, 20/3 = 6.67…, 10 → [0, 3, 7, 10].
      expect(_offsets(const Stagger.evenly(over: Time.frames(10)), 4), [0, 3, 7, 10]);
    });

    test('a single child gets the lone zero offset (no division by zero)', () {
      expect(_offsets(const Stagger.evenly(over: Time.frames(60)), 1), [0]);
    });

    test('a relative `over` resolves against the element scope', () {
      const scope = TimeScopeData(fps: 30, startFrame: 0, durationFrames: 120);
      expect(_offsets(Stagger.evenly(over: 0.5.relative), 3, scope: scope), [0, 30, 60]);
    });
  });

  group('staggerOffsetFrames — Stagger.from (D19 origin orders)', () {
    test('start leads from the first child in natural order', () {
      expect(_offsets(const Stagger.from(StaggerOrigin.start, gap: Time.frames(2)), 4), [
        0,
        2,
        4,
        6,
      ]);
    });

    test('end reverses the order: the last child leads', () {
      expect(_offsets(const Stagger.from(StaggerOrigin.end, gap: Time.frames(2)), 4), [
        6,
        4,
        2,
        0,
      ]);
    });

    test('center on 5: the middle leads and ties go to the lower index', () {
      // Ranks |2i−4| = [4, 2, 0, 2, 4]; sorted with lower-index tie-break the
      // wave order is 2, 1, 3, 0, 4 → step positions [3, 1, 0, 2, 4].
      expect(_offsets(const Stagger.from(StaggerOrigin.center, gap: Time.frames(2)), 5), [
        6,
        2,
        0,
        4,
        8,
      ]);
    });

    test('center on an even count: the lower middle child leads', () {
      // Ranks |2i−3| = [3, 1, 1, 3] → wave order 1, 2, 0, 3.
      expect(_offsets(const Stagger.from(StaggerOrigin.center, gap: Time.frames(2)), 4), [
        4,
        0,
        2,
        6,
      ]);
    });

    test('edges on 4: the outer pair leads, first child first', () {
      // Ranks min(i, 3−i) = [0, 1, 1, 0] → wave order 0, 3, 1, 2.
      expect(_offsets(const Stagger.from(StaggerOrigin.edges, gap: Time.frames(3)), 4), [
        0,
        6,
        9,
        3,
      ]);
    });

    test("the default gap is 80 ms (the spec's recurring example gap)", () {
      // 80 ms at 30 fps resolves once to round(2.4) = 2 frames.
      expect(_offsets(const Stagger.from(StaggerOrigin.start), 3), [0, 2, 4]);
    });
  });

  group('staggerOffsetFrames — totality and determinism', () {
    test('zero children produce zero offsets', () {
      expect(_offsets(Stagger.each(0.08.seconds), 0), isEmpty);
    });

    test('identical inputs produce identical offsets, call after call', () {
      const stagger = Stagger.from(StaggerOrigin.edges, gap: Time.ms(80));
      expect(_offsets(stagger, 6), _offsets(stagger, 6));
      expect(_offsets(stagger, 6), _offsets(stagger, 6));
    });
  });
}
