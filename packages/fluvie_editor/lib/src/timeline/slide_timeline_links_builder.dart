part of 'slide_timeline_model.dart';

/// One bar's link-relevant facts, collected while bars build so links can
/// resolve after every track exists.
final class _BarFacts {
  const _BarFacts({
    required this.barId,
    required this.elementId,
    required this.index,
    required this.at,
    required this.delayFrames,
    required this.start,
    required this.end,
  });

  final String barId;
  final String elementId;
  final int index;
  final Object? at;
  final int delayFrames;
  final double start;
  final double end;
}

/// The trigger links between the slide's bars, resolved from the facts the
/// bar pass collected once every track exists.
extension _LinkBuilding on _ModelBuilder {
  /// Resolves the collected trigger facts into links: `previous` chains to
  /// the same element's preceding bar, `whenEnds`/`whenStarts` to the bar
  /// closing (or opening) the anchor element's timeline. Triggers whose
  /// anchor lives off this slide (or on a bar-less element) draw nothing.
  List<TimelineLink> buildLinks(TimelineLinkPalette linkPalette) {
    final links = <TimelineLink>[];
    for (final fact in facts) {
      final link = _linkOf(fact, linkPalette);
      if (link != null) links.add(link);
    }
    return links;
  }

  TimelineLink? _linkOf(_BarFacts fact, TimelineLinkPalette linkPalette) {
    final label = fact.delayFrames > 0 ? '+${fact.delayFrames}f' : null;
    final at = fact.at;
    if (at == 'previous' && fact.index > 0) {
      return TimelineLink(
        id: fact.barId,
        fromBarId: fact.barId,
        toBarId: '${fact.elementId}:${fact.index - 1}',
        toEdge: TimelineLinkEdge.end,
        color: linkPalette.ends,
        label: label,
      );
    }
    if (at is! Map<String, Object?>) return null;
    final kind = at['kind'];
    if (kind != 'whenEnds' && kind != 'whenStarts') return null;
    final anchor = at['anchor'];
    final targetId = anchorOf.entries
        .where((entry) => entry.value == anchor)
        .map((entry) => entry.key)
        .firstOrNull;
    if (targetId == null) return null;
    final targetBars = facts.where((other) => other.elementId == targetId);
    if (targetBars.isEmpty) return null;
    final ends = kind == 'whenEnds';
    final target = targetBars.reduce(
      (a, b) => ends ? (b.end > a.end ? b : a) : (b.start < a.start ? b : a),
    );
    return TimelineLink(
      id: fact.barId,
      fromBarId: fact.barId,
      toBarId: target.barId,
      toEdge: ends ? TimelineLinkEdge.end : TimelineLinkEdge.start,
      color: ends ? linkPalette.ends : linkPalette.starts,
      label: label,
    );
  }
}

/// Whether a raw `at` value is a composition-level trigger the presenter
/// rejects inside a `Stop` — the live-violation rule, mirrored.
bool _isCompositionTrigger(Object? at) =>
    at is Map<String, Object?> && const {'whenEnds', 'whenStarts', 'beat'}.contains(at['kind']);
