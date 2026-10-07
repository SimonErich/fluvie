// The timeline's snapping math. Pure and frame-based: the caller converts
// pixels to frames with its own zoom, so a snap decided at one zoom is the
// same snap at another and a test never reasons about pixels.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

TimelineSnapEngine _engine({
  List<TimelineSnapCandidate> candidates = const [],
  int tolerance = 6,
}) => TimelineSnapEngine(candidates: candidates, tolerance: tolerance);

const _playhead = TimelineSnapCandidate(100, TimelineSnapKind.playhead);
const _barEdge = TimelineSnapCandidate(100, TimelineSnapKind.barEdge);
const _boundary = TimelineSnapCandidate(100, TimelineSnapKind.sceneBoundary);

void main() {
  group('with nothing to catch it', () {
    test('an empty engine never snaps', () {
      final result = _engine().snap(42);

      expect(result.frame, 42);
      expect(result.snapped, isFalse);
      expect(result.candidate, isNull);
    });

    test('a candidate outside the tolerance is not close enough', () {
      final result = _engine(candidates: [_boundary]).snap(93);

      expect(result.frame, 93);
      expect(result.snapped, isFalse);
    });

    test('a candidate exactly at the tolerance still catches', () {
      // The boundary of the boundary: off by one here means a snap that is
      // reachable in theory and not in practice.
      final result = _engine(candidates: [_boundary]).snap(94);

      expect(result.frame, 100);
      expect(result.snapped, isTrue);
    });
  });

  group('the nearest candidate wins', () {
    test('from either side', () {
      final engine = _engine(candidates: [_boundary]);

      expect(engine.snap(97).frame, 100);
      expect(engine.snap(103).frame, 100);
    });

    test('over a further one', () {
      final engine = _engine(
        candidates: const [
          TimelineSnapCandidate(100, TimelineSnapKind.barEdge),
          TimelineSnapCandidate(104, TimelineSnapKind.barEdge),
        ],
      );

      expect(engine.snap(103).frame, 104);
      expect(engine.snap(101).frame, 100);
    });

    test('and the result names what it landed on', () {
      final result = _engine(candidates: [_playhead]).snap(98);

      expect(result.candidate, _playhead);
      expect(result.candidate!.kind, TimelineSnapKind.playhead);
    });
  });

  group('ties', () {
    test('go to the stronger kind, whatever the list order', () {
      // A playhead the author parked somewhere beats a boundary they never
      // chose. Both orders must agree, or the result depends on how the
      // candidates happened to be collected.
      expect(
        _engine(candidates: const [_boundary, _playhead]).snap(97).candidate!.kind,
        TimelineSnapKind.playhead,
      );
      expect(
        _engine(candidates: const [_playhead, _boundary]).snap(97).candidate!.kind,
        TimelineSnapKind.playhead,
      );
    });

    test('a bar edge beats a scene boundary', () {
      expect(
        _engine(candidates: const [_boundary, _barEdge]).snap(97).candidate!.kind,
        TimelineSnapKind.barEdge,
      );
    });

    test('within one kind, the earlier candidate wins', () {
      final engine = _engine(
        candidates: const [
          TimelineSnapCandidate(104, TimelineSnapKind.barEdge),
          TimelineSnapCandidate(96, TimelineSnapKind.barEdge),
        ],
      );

      // 100 is four frames from each; the earlier one takes it.
      expect(engine.snap(100).frame, 96);
    });
  });

  group('the bypass', () {
    test('returns the frame untouched however close a candidate is', () {
      final result = _engine(candidates: [_playhead]).snap(100, bypass: true);

      expect(result.frame, 100);
      expect(result.snapped, isFalse, reason: 'landing on it is not snapping to it');
    });

    test('bypasses a bar drag too', () {
      final result = _engine(candidates: [_playhead]).snapBar(98, length: 30, bypass: true);

      expect(result.frame, 98);
      expect(result.snapped, isFalse);
    });
  });

  group('a bar catches on either edge', () {
    test('its leading edge', () {
      final result = _engine(candidates: [_boundary]).snapBar(97, length: 30);

      expect(result.frame, 100);
      expect(result.candidate, _boundary);
    });

    test('its trailing edge, placing the bar so that edge lands', () {
      // Snapping only the leading edge lets the trailing one drift past a
      // boundary it visibly touches, which reads as the timeline ignoring it.
      final result = _engine(candidates: [_boundary]).snapBar(68, length: 30);

      expect(result.frame, 70, reason: 'so the end lands on 100');
      expect(result.candidate, _boundary);
    });

    test('the closer edge wins when both catch', () {
      final engine = _engine(
        candidates: const [
          TimelineSnapCandidate(100, TimelineSnapKind.barEdge),
          TimelineSnapCandidate(128, TimelineSnapKind.barEdge),
        ],
      );

      // Start 98 is 2 from 100; end 128 is exactly on 128. The end is closer.
      final result = engine.snapBar(98, length: 30);
      expect(result.frame, 98);
    });

    test('a tie goes to the leading edge, which is under the pointer', () {
      final engine = _engine(
        candidates: const [
          TimelineSnapCandidate(100, TimelineSnapKind.barEdge),
          TimelineSnapCandidate(130, TimelineSnapKind.barEdge),
        ],
      );

      // Start 98 is 2 from 100; end 128 is 2 from 130. Leading wins.
      expect(engine.snapBar(98, length: 30).frame, 100);
    });

    test('neither edge catching leaves the bar where it was dragged', () {
      final result = _engine(candidates: [_boundary]).snapBar(40, length: 30);

      expect(result.frame, 40);
      expect(result.snapped, isFalse);
    });
  });

  group('the engine holds still', () {
    test('the same query always answers the same', () {
      final engine = _engine(candidates: const [_playhead, _boundary]);

      for (var i = 0; i < 20; i++) {
        expect(engine.snap(97).frame, 100);
      }
    });

    test('a zero tolerance snaps only on an exact hit', () {
      final engine = _engine(candidates: [_boundary], tolerance: 0);

      expect(engine.snap(100).snapped, isTrue);
      expect(engine.snap(101).snapped, isFalse);
    });
  });
}
