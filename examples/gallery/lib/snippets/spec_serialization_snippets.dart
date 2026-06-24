// Compiled, tested snippets for documentation/guides/authoring-with-specs.md.
// Each `#docregion` flows into one fence via a `<!-- code-excerpt -->` marker,
// so the page can never drift from the real serialization API.

import 'dart:convert';

import 'package:fluvie/fluvie.dart';

/// Loads a spec document (JSON text) and builds a renderable [Video].
Video loadSpec(String jsonText) {
  // #docregion load
  final spec = VideoSpec.fromJson(jsonDecode(jsonText) as Map<String, Object?>);
  final video = buildVideo(spec);
  // #enddocregion load
  return video;
}

/// Serializes a spec back to JSON text.
String saveSpec(VideoSpec spec) {
  // #docregion save
  final jsonText = jsonEncode(spec.toJson());
  // #enddocregion save
  return jsonText;
}

/// The stable content digest, for caching and reproducible output.
String specDigest(VideoSpec spec) {
  // #docregion digest
  final id = spec.digest();
  // #enddocregion digest
  return id;
}
