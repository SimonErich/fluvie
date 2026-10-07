import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie_editor/src/commands/copied_slide.dart';
import 'package:meta/meta.dart' show immutable;

/// What a copy carries: spec JSON, document-independent.
///
/// An `elements` envelope holds element JSON with fraction-space
/// transforms; a `slides` envelope holds whole scenes plus their editor
/// metadata. Either pastes into any document — paste re-mints the ids on
/// the way in. [sourceIds] — every id in the copied trees at copy time —
/// lets an element paste detect "same slide" (the originals are still
/// there) and apply the small offset instead of a pixel-exact overlap.
@immutable
final class ClipboardEnvelope {
  /// Wraps the copied [elements] (z-order, ids included) and the
  /// [sourceIds] they carried when copied.
  const ClipboardEnvelope({required this.elements, required this.sourceIds})
    : kind = 'elements',
      slides = const [],
      effects = const [];

  /// Wraps whole copied [slides] (scene JSON plus editor metadata).
  const ClipboardEnvelope.slides(this.slides)
    : kind = 'slides',
      elements = const [],
      effects = const [],
      sourceIds = const {};

  /// Wraps one element's copied effect stack, in stack order.
  ///
  /// Effects carry no ids, so unlike the elements envelope there is nothing
  /// to re-mint on paste — the paste's deep copy is the whole discipline.
  const ClipboardEnvelope.effects(this.effects)
    : kind = 'effects',
      elements = const [],
      slides = const [],
      sourceIds = const {};

  /// What the envelope carries: `elements` or `slides`.
  final String kind;

  /// The copied element JSON, in z-order (empty in a slides envelope).
  final List<Map<String, Object?>> elements;

  /// The copied slides (empty in an elements envelope).
  final List<CopiedSlide> slides;

  /// The copied effect stack (empty unless the kind is `effects`).
  final List<Map<String, Object?>> effects;

  /// Every element id inside the copied trees, as copied.
  final Set<String> sourceIds;

  /// The envelope's JSON form (what the system clipboard carries as text).
  Map<String, Object?> toJson() => {
    'fluvieClipboard': 1,
    'kind': kind,
    if (kind == 'elements') 'elements': elements,
    if (kind == 'elements') 'source': [...sourceIds],
    if (kind == 'slides') 'slides': [for (final slide in slides) slide.toJson()],
    if (kind == 'effects') 'effects': effects,
  };

  /// Parses clipboard [text] back into an envelope, or null for anything
  /// that is not one (foreign text, other JSON, an unknown version).
  static ClipboardEnvelope? tryParse(String? text) {
    if (text == null || text.isEmpty) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, Object?>) return null;
    if (decoded['fluvieClipboard'] != 1) return null;
    if (decoded['kind'] == 'slides') {
      final slides = decoded['slides'];
      if (slides is! List) return null;
      return ClipboardEnvelope.slides([
        for (final entry in slides)
          if (CopiedSlide.tryParse(entry) case final CopiedSlide slide) slide,
      ]);
    }
    if (decoded['kind'] == 'effects') {
      final effects = decoded['effects'];
      if (effects is! List) return null;
      return ClipboardEnvelope.effects([...effects.whereType<Map<String, Object?>>()]);
    }
    if (decoded['kind'] != 'elements') return null;
    final elements = decoded['elements'];
    if (elements is! List) return null;
    final source = decoded['source'];
    return ClipboardEnvelope(
      elements: [...elements.whereType<Map<String, Object?>>()],
      sourceIds: source is List ? {...source.whereType<String>()} : const {},
    );
  }
}

/// The editor's clipboard: the system clipboard first (a JSON text payload,
/// so copies travel across documents and app instances), an in-memory slot
/// as the fallback where the platform clipboard is unavailable or holds
/// foreign text.
final class EditorClipboard {
  ClipboardEnvelope? _memory;

  /// Writes [envelope] to the system clipboard and mirrors it in memory.
  Future<void> write(ClipboardEnvelope envelope) async {
    _memory = envelope;
    try {
      await Clipboard.setData(ClipboardData(text: jsonEncode(envelope.toJson())));
    } on Exception {
      // The memory slot already holds the copy; paste still works here.
    }
  }

  /// The last copied envelope: the system clipboard's if it parses, the
  /// in-memory fallback otherwise, null when neither holds one.
  Future<ClipboardEnvelope?> read() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final parsed = ClipboardEnvelope.tryParse(data?.text);
      if (parsed != null) return parsed;
    } on Exception {
      // Fall through to the memory slot.
    }
    return _memory;
  }
}

/// The clipboard for the mounted editor scope.
final editorClipboardProvider = Provider<EditorClipboard>((ref) => EditorClipboard());
