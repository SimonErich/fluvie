/// A video sample located in a finished Veo operation: a URI or inline bytes.
typedef VeoSample = ({String? uri, String? inlineBase64});

/// Extracts the first video sample from a finished Veo [operation], or null.
///
/// Handles both delivery shapes Veo uses: a downloadable `uri` and inline
/// `bytesBase64Encoded`. Returns null when neither is present.
VeoSample? veoSample(Map<String, Object?> operation) {
  final response = operation['response'];
  if (response is! Map<String, Object?>) {
    return null;
  }
  final samples = _generatedSamples(response);
  for (final sample in samples) {
    if (sample is! Map<String, Object?>) {
      continue;
    }
    final video = sample['video'];
    if (video is! Map<String, Object?>) {
      continue;
    }
    final uri = video['uri'];
    final inline = video['bytesBase64Encoded'];
    if (uri is String) {
      return (uri: uri, inlineBase64: null);
    }
    if (inline is String) {
      return (uri: null, inlineBase64: inline);
    }
  }
  return null;
}

/// The `generatedSamples` list from a Veo operation response, or empty.
List<Object?> _generatedSamples(Map<String, Object?> response) {
  final wrapper = response['generateVideoResponse'];
  if (wrapper is! Map<String, Object?>) {
    return const [];
  }
  final samples = wrapper['generatedSamples'];
  return samples is List ? samples : const [];
}
