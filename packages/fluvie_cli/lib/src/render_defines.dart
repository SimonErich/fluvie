import 'dart:io';

/// Builds the capture `--dart-define` set the harness reads, one helper per
/// authoring mode.
///
/// These are the single source of truth for the define *names*
/// (`FLUVIE_RENDER_SPEC`, `FLUVIE_AI_PROMPT`, ...): the CLI commands and the
/// render server both go through them, so the two cannot drift. File paths are
/// absolutized here because the harness runs with a different working directory
/// than the caller.

/// Defines for rendering a serialized `VideoSpec` document at [specPath]
/// instead of a registry key.
Map<String, String> specDefines(String specPath) => {
  'FLUVIE_RENDER_SPEC': File(specPath).absolute.path,
};

/// Defines for authoring a `VideoSpec` from the natural-language [prompt],
/// writing the result to [specOut]. [provider] overrides the LLM backend when
/// non-empty (otherwise the harness reads `FLUVIE_AI_PROVIDER` from the
/// environment).
Map<String, String> generateDefines({
  required String prompt,
  required String specOut,
  String? provider,
}) => {
  'FLUVIE_AI_PROMPT': prompt,
  'FLUVIE_RENDER_SPEC_OUT': File(specOut).absolute.path,
  if (provider != null && provider.isNotEmpty) 'FLUVIE_AI_PROVIDER': provider,
};

/// Defines for refining the base spec at [baseSpecPath] with the
/// natural-language [change], writing the edited spec to [specOut]. [provider]
/// overrides the LLM backend when non-empty.
Map<String, String> editDefines({
  required String baseSpecPath,
  required String change,
  required String specOut,
  String? provider,
}) => {
  'FLUVIE_AI_BASE_SPEC': File(baseSpecPath).absolute.path,
  'FLUVIE_AI_PROMPT': change,
  'FLUVIE_RENDER_SPEC_OUT': File(specOut).absolute.path,
  if (provider != null && provider.isNotEmpty) 'FLUVIE_AI_PROVIDER': provider,
};
