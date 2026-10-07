import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter/foundation.dart' show immutable;

/// The record format this build writes; readers reject anything else so a
/// future shape change never resurrects as a scrambled recovery.
const int autosaveFormatVersion = 1;

/// One autosaved working document: the deck's canonical JSON text, when it
/// was written, and the editor-side document digest it covers (the recovery
/// prompt compares that digest against the freshly opened file).
@immutable
final class AutosaveRecord {
  /// Describes one autosave.
  const AutosaveRecord({
    required this.json,
    required this.savedAt,
    required this.digest,
    this.version = autosaveFormatVersion,
  });

  /// The document's JSON text, exactly what a save would have written.
  final String json;

  /// When the autosave was written.
  final DateTime savedAt;

  /// The editor-side document digest of [json] at write time.
  final String digest;

  /// The record format version stamp.
  final int version;

  /// The JSON form the stores persist.
  Map<String, Object?> toJson() => {
    'version': version,
    'json': json,
    'digest': digest,
    'savedAt': savedAt.millisecondsSinceEpoch,
  };

  /// Parses one stored record, or null for anything that is not this
  /// format version with a document and a digest. A missing timestamp
  /// reads as the epoch (display-only data never blocks a recovery).
  static AutosaveRecord? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    if (json['version'] != autosaveFormatVersion) return null;
    final text = json['json'];
    final digest = json['digest'];
    if (text is! String || text.isEmpty) return null;
    if (digest is! String || digest.isEmpty) return null;
    final savedAt = json['savedAt'];
    return AutosaveRecord(
      json: text,
      digest: digest,
      savedAt: DateTime.fromMillisecondsSinceEpoch(savedAt is int ? savedAt : 0),
    );
  }
}

/// The stored text form of [record].
String encodeAutosaveRecord(AutosaveRecord record) => jsonEncode(record.toJson());

/// Parses a stored record; anything unreadable (garbage, foreign JSON, an
/// unknown version) reads as absent rather than crashing an open.
AutosaveRecord? decodeAutosaveRecord(String? text) {
  if (text == null || text.isEmpty) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException {
    return null;
  }
  return AutosaveRecord.fromJson(decoded);
}

/// How the quiet indicator and the recovery prompt phrase [savedAt] against
/// [now]: "just now" under a minute (clock skew included), minutes and
/// hours as "ago", anything a day or older as a plain date.
String relativeTimeLabel(DateTime savedAt, DateTime now) {
  final elapsed = now.difference(savedAt);
  if (elapsed.inMinutes < 1) return 'just now';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes}m ago';
  if (elapsed.inHours < 24) return '${elapsed.inHours}h ago';
  String pad(int part) => part.toString().padLeft(2, '0');
  return 'on ${savedAt.year}-${pad(savedAt.month)}-${pad(savedAt.day)}';
}
