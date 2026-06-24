/// The task id from a Suno generate response, or null.
///
/// Accepts both the nested `data.taskId` shape and a flat top-level `id`.
String? sunoTaskId(Map<String, Object?> json) {
  final data = json['data'];
  if (data is Map<String, Object?>) {
    final nested = data['taskId'] ?? data['id'];
    if (nested is String) {
      return nested;
    }
  }
  final flat = json['taskId'] ?? json['id'];
  return flat is String ? flat : null;
}

/// The first finished audio URL from a Suno record response, or null.
///
/// Looks through `data.response.sunoData[]` for an `audioUrl` (the camelCase
/// form) or a snake_case `audio_url`, returning the first non-empty value.
String? sunoAudioUrl(Map<String, Object?> json) {
  final data = json['data'];
  if (data is! Map<String, Object?>) {
    return null;
  }
  final response = data['response'];
  if (response is! Map<String, Object?>) {
    return null;
  }
  final tracks = response['sunoData'];
  if (tracks is! List) {
    return null;
  }
  for (final track in tracks) {
    if (track is! Map<String, Object?>) {
      continue;
    }
    final url = track['audioUrl'] ?? track['audio_url'];
    if (url is String && url.isNotEmpty) {
      return url;
    }
  }
  return null;
}
