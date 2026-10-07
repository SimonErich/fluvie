import 'dart:convert' show jsonEncode;

import 'package:meta/meta.dart';

/// How a [SharedPair] was found.
enum SharedPairSource {
  /// Both elements carry the same author-typed `shared` id.
  explicitId,

  /// The elements are the same content — same type, equal content props —
  /// so they read as one element duplicated across the slides.
  content,
}

/// One pairing between an element of the previous slide and an element of
/// the current slide — the raw material of a `SharedElement` hero morph.
@immutable
final class SharedPair {
  /// Pairs [previousId] with [currentId], found through [source].
  const SharedPair({
    required this.previousId,
    required this.currentId,
    required this.source,
    this.sharedId,
  });

  /// The paired element on the previous slide.
  final String previousId;

  /// The paired element on the current slide.
  final String currentId;

  /// The author's `shared` id for [SharedPairSource.explicitId] pairs, null
  /// for content pairs (those get an id minted when auto-animate applies).
  final String? sharedId;

  /// How this pair was found.
  final SharedPairSource source;
}

/// The pairing result over one slide boundary: the [pairs] plus what stayed
/// unmatched on each side. Unmatched elements get no invented motion — they
/// ride the slide's authored transition.
@immutable
final class SharedPairing {
  /// Wraps the engine output.
  const SharedPairing({
    required this.pairs,
    required this.unmatchedPrevious,
    required this.unmatchedCurrent,
  });

  /// The matched pairs, in the current slide's document order.
  final List<SharedPair> pairs;

  /// Previous-slide element ids no pair claimed.
  final List<String> unmatchedPrevious;

  /// Current-slide element ids no pair claimed.
  final List<String> unmatchedCurrent;
}

/// Matches the elements of two adjacent slides: explicit `shared` ids that
/// appear on both sides pair first (the author wins), then content identity
/// — same type and equal content props, transform and animation ignored —
/// pairs what reads as the same element duplicated across the slides,
/// tie-broken by document order.
///
/// [previous] and [current] are the slides' `children` JSON; group children
/// are walked depth-first. Elements without an `id` are skipped. An element
/// carrying any `shared` id never content-matches (its id is the author's
/// word, even when nothing on the other side answers it), invisible
/// elements never content-match, and groups content-match never — only
/// their children do.
SharedPairing pairElements({
  required List<Map<String, Object?>> previous,
  required List<Map<String, Object?>> current,
}) {
  final prev = _flatten(previous);
  final curr = _flatten(current);
  final prevByShared = _firstBySharedId(prev);
  final currByShared = _firstBySharedId(curr);
  final pairs = <SharedPair>[];
  final pairedPrev = <String>{};
  final pairedCurr = <String>{};
  for (final entry in currByShared.entries) {
    final partner = prevByShared[entry.key];
    if (partner == null) continue;
    pairs.add(
      SharedPair(
        previousId: partner.id,
        currentId: entry.value.id,
        sharedId: entry.key,
        source: SharedPairSource.explicitId,
      ),
    );
    pairedPrev.add(partner.id);
    pairedCurr.add(entry.value.id);
  }
  final candidates = [
    for (final element in prev)
      if (!pairedPrev.contains(element.id) && element.contentMatchable) element,
  ];
  for (final element in curr) {
    if (pairedCurr.contains(element.id) || !element.contentMatchable) continue;
    final index = candidates.indexWhere((c) => c.signature == element.signature);
    if (index < 0) continue;
    final partner = candidates.removeAt(index);
    pairs.add(
      SharedPair(
        previousId: partner.id,
        currentId: element.id,
        source: SharedPairSource.content,
      ),
    );
    pairedPrev.add(partner.id);
    pairedCurr.add(element.id);
  }
  return SharedPairing(
    pairs: List.unmodifiable(pairs),
    unmatchedPrevious: List.unmodifiable([
      for (final element in prev)
        if (!pairedPrev.contains(element.id)) element.id,
    ]),
    unmatchedCurrent: List.unmodifiable([
      for (final element in curr)
        if (!pairedCurr.contains(element.id)) element.id,
    ]),
  );
}

/// A canonical, key-order-independent JSON encoding — the content-equality
/// currency of the pairing engine (and of anyone comparing spec fragments).
String canonicalJson(Object? value) => switch (value) {
  Map<String, Object?>() =>
    '{${([for (final key in value.keys) key]..sort()).map((key) => '${jsonEncode(key)}:${canonicalJson(value[key])}').join(',')}}',
  List<Object?>() => '[${value.map(canonicalJson).join(',')}]',
  String() => jsonEncode(value),
  _ => '$value',
};

/// The keys content identity ignores: element identity, placement, motion,
/// timing, and visibility — everything that changes across slides without
/// changing what the element *is* (the mirror of fluvie's reserved element
/// keys).
const Set<String> _identityKeys = {
  'id',
  'type',
  'transform',
  'anchor',
  'shared',
  'visible',
  'show',
  'animate',
};

final class _Walked {
  _Walked(this.element)
    : id = element['id']! as String,
      shared = element['shared'] is String ? element['shared']! as String : null;

  final Map<String, Object?> element;
  final String id;
  final String? shared;

  bool get contentMatchable =>
      shared == null && element['visible'] != false && element['type'] != 'Group';

  late final String signature =
      '${element['type']}|${canonicalJson({
        for (final entry in element.entries)
          if (!_identityKeys.contains(entry.key)) entry.key: entry.value,
      })}';
}

/// Depth-first flatten in document order, groups followed by their children;
/// elements without a string id are dropped.
List<_Walked> _flatten(List<Map<String, Object?>> elements) => [
  for (final element in elements) ...[
    if (element['id'] is String) _Walked(element),
    if (element['type'] == 'Group' && element['children'] is List)
      ..._flatten((element['children']! as List).whereType<Map<String, Object?>>().toList()),
  ],
];

/// The first element per `shared` id, in document order.
Map<String, _Walked> _firstBySharedId(List<_Walked> elements) {
  final byId = <String, _Walked>{};
  for (final element in elements) {
    final shared = element.shared;
    if (shared != null) byId.putIfAbsent(shared, () => element);
  }
  return byId;
}
