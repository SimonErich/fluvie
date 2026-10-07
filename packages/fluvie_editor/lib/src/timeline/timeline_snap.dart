import 'package:flutter/foundation.dart' show immutable;

/// What a timeline snap line is, so a drawing can say why the bar stopped.
///
/// Ordered by how strongly it should win a tie: a playhead the author put
/// somewhere deliberately beats a bar edge, which beats a scene boundary they
/// never chose.
enum TimelineSnapKind {
  /// The playhead.
  playhead,

  /// An in or out mark.
  mark,

  /// Another bar's start or end.
  barEdge,

  /// A scene boundary.
  sceneBoundary,
}

/// One candidate the timeline can snap to.
@immutable
final class TimelineSnapCandidate {
  /// A candidate at [frame].
  const TimelineSnapCandidate(this.frame, this.kind);

  /// Where it sits, in composition frames.
  final int frame;

  /// What it is.
  final TimelineSnapKind kind;

  @override
  bool operator ==(Object other) =>
      other is TimelineSnapCandidate && other.frame == frame && other.kind == kind;

  @override
  int get hashCode => Object.hash(frame, kind);

  @override
  String toString() => 'TimelineSnapCandidate($frame, ${kind.name})';
}

/// What a snap query decided: where the bar goes and what it landed on.
@immutable
final class TimelineSnap {
  /// A snap to [frame] against [candidate], or a free move when [candidate] is
  /// null.
  const TimelineSnap({required this.frame, this.candidate});

  /// The frame the dragged edge should take.
  final int frame;

  /// What it snapped to, or null when nothing was close enough.
  final TimelineSnapCandidate? candidate;

  /// Whether the query snapped at all.
  bool get snapped => candidate != null;
}

/// The pure snapping math of one timeline drag.
///
/// Built at pointer-down from everything the bar could land on, then asked per
/// pointer update. Pure and frame-based: the caller converts pixels to frames
/// with its own zoom, so a snap decided at one zoom is the same snap at
/// another, and a test never has to reason about pixels.
///
/// Tolerance is in **frames**, not pixels, and the caller derives it from a
/// pixel budget divided by the zoom. That way a snap feels the same distance
/// away on screen however far the timeline is zoomed in, which is what an
/// author's hand expects.
final class TimelineSnapEngine {
  /// An engine over [candidates] with a [tolerance] in frames.
  TimelineSnapEngine({required List<TimelineSnapCandidate> candidates, this.tolerance = 6})
    : assert(tolerance >= 0, 'tolerance cannot be negative'),
      _candidates = List.unmodifiable(candidates);

  final List<TimelineSnapCandidate> _candidates;

  /// How far, in frames, a candidate can be and still catch the drag.
  final int tolerance;

  /// Where a dragged edge at [frame] should land.
  ///
  /// The nearest candidate within [tolerance] wins. An exact tie goes to the
  /// stronger kind — a playhead the author parked somewhere beats a scene
  /// boundary they never chose — and a tie within one kind goes to the earlier
  /// candidate, so the result never depends on list order.
  ///
  /// [bypass] returns the frame untouched: one modifier means one thing across
  /// the app, and on the canvas that modifier already means "ignore snapping".
  TimelineSnap snap(int frame, {bool bypass = false}) {
    if (bypass || _candidates.isEmpty) return TimelineSnap(frame: frame);
    TimelineSnapCandidate? best;
    var bestDistance = tolerance + 1;
    for (final candidate in _candidates) {
      final distance = (candidate.frame - frame).abs();
      if (distance > tolerance) continue;
      if (best == null || distance < bestDistance) {
        best = candidate;
        bestDistance = distance;
        continue;
      }
      if (distance == bestDistance && _beats(candidate, best)) best = candidate;
    }
    return best == null
        ? TimelineSnap(frame: frame)
        : TimelineSnap(frame: best.frame, candidate: best);
  }

  /// Where a bar of [length] frames dragged so its start is at [frame] should
  /// land, considering **both** its edges.
  ///
  /// A bar has two edges and an author expects either to catch. Snapping only
  /// the leading edge makes the trailing one drift past a boundary it visibly
  /// touches, which reads as the timeline ignoring them.
  TimelineSnap snapBar(int frame, {required int length, bool bypass = false}) {
    if (bypass) return TimelineSnap(frame: frame);
    final start = snap(frame, bypass: bypass);
    final end = snap(frame + length, bypass: bypass);
    if (!start.snapped) {
      return end.snapped
          ? TimelineSnap(frame: end.frame - length, candidate: end.candidate)
          : start;
    }
    if (!end.snapped) return start;
    // Both caught: the closer edge wins, and a tie goes to the leading one,
    // because that is the edge under the pointer.
    final startDistance = (start.frame - frame).abs();
    final endDistance = (end.frame - (frame + length)).abs();
    return endDistance < startDistance
        ? TimelineSnap(frame: end.frame - length, candidate: end.candidate)
        : start;
  }

  /// Whether [a] should win a tie against [b].
  static bool _beats(TimelineSnapCandidate a, TimelineSnapCandidate b) {
    if (a.kind != b.kind) return a.kind.index < b.kind.index;
    return a.frame < b.frame;
  }
}
