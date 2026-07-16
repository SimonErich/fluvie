import 'package:flutter/foundation.dart' show listEquals;
import 'package:meta/meta.dart';

/// The resolved notes for one `(slide, step)` position: what the notes panel
/// and the speaker window show.
///
/// Produced by the notes compiler — the scene default merged with the active
/// step's override, per the documented rule (step text replaces, highlights
/// append).
@immutable
final class SlideNotes {
  /// Creates resolved notes.
  const SlideNotes({this.text, this.highlights = const []});

  /// The prose to say, or `null` when this position has none.
  final String? text;

  /// The quick-glance bullets, scene first, step additions after.
  final List<String> highlights;

  /// Whether there is nothing to show for this position.
  bool get isEmpty => text == null && highlights.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is SlideNotes && other.text == text && listEquals(other.highlights, highlights);

  @override
  int get hashCode => Object.hash(SlideNotes, text, Object.hashAll(highlights));

  @override
  String toString() => 'SlideNotes(${text ?? '-'}, highlights: ${highlights.length})';
}
