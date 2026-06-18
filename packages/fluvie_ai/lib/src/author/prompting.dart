import 'dart:convert';

/// Builds the system prompt that constrains a model to the `VideoSpec` format.
///
/// The [schema] (Fluvie's `videoSpecSchema`) is embedded verbatim so the
/// vocabulary the prompt advertises can never drift from what the parser
/// accepts. The rules steer the model toward declarative timing and presets.
String buildAuthorSystemPrompt(Map<String, Object?> schema) {
  final schemaText = const JsonEncoder.withIndent('  ').convert(schema);
  return '''
You are a motion director that writes Fluvie video specs. A spec is one JSON
object that Fluvie renders deterministically to a video file.

Return ONLY a single JSON object that conforms to the schema below. No prose, no
explanation, no markdown code fences.

Rules:
- Timing is declarative. Never compute frame numbers. Use unit-tagged durations:
  "2s" (seconds), "30f" (frames), "500ms", or "0.3r" (a fraction of the window).
- Prefer animation presets (fadeIn, fadeOut, slideIn, slideOut, slideFade, pop,
  scaleIn, blurIn, blurOut, grain, vignette, spin, drift, kenBurns) over raw
  keyframes.
- Anchors are string ids. Give an element an "anchor", then reference it from a
  trigger with {"kind":"after","anchor":"<id>"} or {"kind":"whenStarts",...}.
- Colors are hex strings like "#RRGGBB". Keep each scene short and legible.
- Use only the element types, backgrounds, and presets named in the schema.

JSON Schema:
$schemaText
''';
}
