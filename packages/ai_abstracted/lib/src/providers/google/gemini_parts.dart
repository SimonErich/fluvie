/// Inline binary data extracted from a Gemini `inlineData` part.
typedef InlineData = ({String mimeType, String data});

/// Returns the parts list of the first candidate, or an empty list.
List<Object?> _firstParts(Map<String, Object?> json) {
  final candidates = json['candidates'];
  if (candidates is! List || candidates.isEmpty) {
    return const [];
  }
  final first = candidates.first;
  if (first is! Map<String, Object?>) {
    return const [];
  }
  final content = first['content'];
  if (content is! Map<String, Object?>) {
    return const [];
  }
  final parts = content['parts'];
  return parts is List ? parts : const [];
}

/// The first `inlineData` (base64 image) across the first candidate's parts.
///
/// Returns null when the response carries no inline data. The default MIME type
/// is `image/png` when the part omits one.
InlineData? firstInlineData(Map<String, Object?> json) {
  for (final part in _firstParts(json)) {
    if (part is! Map<String, Object?>) {
      continue;
    }
    final inline = part['inlineData'];
    if (inline is Map<String, Object?>) {
      final data = inline['data'];
      if (data is String) {
        final mime = inline['mimeType'];
        return (mimeType: mime is String ? mime : 'image/png', data: data);
      }
    }
  }
  return null;
}

/// The first text part across the first candidate's parts, or null.
String? firstText(Map<String, Object?> json) {
  for (final part in _firstParts(json)) {
    if (part is Map<String, Object?> && part['text'] is String) {
      return part['text']! as String;
    }
  }
  return null;
}
