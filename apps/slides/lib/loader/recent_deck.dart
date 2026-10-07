import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter/foundation.dart' show immutable;

/// One remembered deck on the open screen: the display name, the file path
/// where one exists (desktop opens and saves; the web has none), and when
/// it was last touched.
@immutable
final class RecentDeck {
  /// Describes one entry.
  const RecentDeck({required this.name, required this.lastOpened, this.path});

  /// The deck's display name (its file name).
  final String name;

  /// The file path, or null where paths mean nothing (the web).
  final String? path;

  /// When the deck was last opened, saved, or renamed.
  final DateTime lastOpened;

  /// The identity recents dedupe on: the path when one exists, the name
  /// otherwise.
  String get key => path ?? name;

  /// The JSON form the stores persist.
  Map<String, Object?> toJson() => {
    'name': name,
    if (path != null) 'path': path,
    'lastOpened': lastOpened.millisecondsSinceEpoch,
  };

  /// Parses one stored entry, or null for anything without a name.
  static RecentDeck? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final name = json['name'];
    if (name is! String || name.isEmpty) return null;
    final path = json['path'];
    final lastOpened = json['lastOpened'];
    return RecentDeck(
      name: name,
      path: path is String ? path : null,
      lastOpened: DateTime.fromMillisecondsSinceEpoch(lastOpened is int ? lastOpened : 0),
    );
  }
}

/// The stored form of a whole recents list.
String encodeRecentDecks(List<RecentDeck> decks) =>
    jsonEncode([for (final deck in decks) deck.toJson()]);

/// Parses a stored recents list; anything unreadable (garbage, foreign
/// JSON, junk entries) reads as absent rather than crashing the picker.
List<RecentDeck> decodeRecentDecks(String? text) {
  if (text == null || text.isEmpty) return const [];
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException {
    return const [];
  }
  if (decoded is! List) return const [];
  return [
    for (final entry in decoded)
      if (RecentDeck.fromJson(entry) case final RecentDeck deck) deck,
  ];
}
