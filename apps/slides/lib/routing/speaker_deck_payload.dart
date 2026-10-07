import 'package:slides/editor/file_media_importer.dart' show isAudioName;

/// Rewrites [deckJson]'s `bundle` references into forms the web speaker popup
/// can resolve on its own, returning a deep copy (the open document is never
/// touched — the rewrite is session-scoped and never saved).
///
/// A popup is another window with its own session, so a bundle value would
/// resolve to nothing there. Image and video values become `network` sources
/// pointing at [urlFor]'s minted URL — on the web an object URL, which is
/// origin-scoped and readable from a same-origin popup for as long as the
/// opener lives. Audio values take the `asset` form with the bundle-relative
/// value verbatim (the code printer's precedent): live playback never mixes
/// audio, so the popup only needs the reference to parse and build. A media
/// value [urlFor] cannot mint falls back to the same asset form, so one
/// missing entry degrades to one missing picture, never a refused deck.
Map<String, Object?> speakerDeckPayload(
  Map<String, Object?> deckJson, {
  required String? Function(String value) urlFor,
}) => _rewriteMap(deckJson, urlFor);

Map<String, Object?> _rewriteMap(Map<String, Object?> node, String? Function(String value) urlFor) {
  final value = node['value'];
  if (node['kind'] == 'bundle' && value is String) {
    if (!isAudioName(value)) {
      final url = urlFor(value);
      if (url != null) return <String, Object?>{'kind': 'network', 'value': url};
    }
    return <String, Object?>{'kind': 'asset', 'value': value};
  }
  return <String, Object?>{
    for (final entry in node.entries) entry.key: _rewrite(entry.value, urlFor),
  };
}

Object? _rewrite(Object? node, String? Function(String value) urlFor) {
  if (node is Map<String, Object?>) return _rewriteMap(node, urlFor);
  if (node is List) return [for (final child in node) _rewrite(child, urlFor)];
  return node;
}
