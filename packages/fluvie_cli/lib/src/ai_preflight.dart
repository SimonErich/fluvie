import 'package:fluvie_cli/src/cli_failure.dart';

/// Checks provider selection and configuration before resolving a harness or
/// downloading tools. Does not make a paid request or disclose secret values.
String validateAiEnvironment(Map<String, String> environment, {String? provider}) {
  final selected = provider ?? environment['FLUVIE_AI_PROVIDER'] ?? 'claude';
  final key = switch (selected) {
    'claude' => 'ANTHROPIC_API_KEY',
    'gemini' => 'GEMINI_API_KEY',
    'mistral' => 'MISTRAL_API_KEY',
    'ollama' => null,
    _ => throw CliFailure(
      'Unknown AI provider "$selected". Choose claude, gemini, mistral, or ollama.',
      code: 'invalid_provider',
    ),
  };
  if (key != null && (environment[key]?.trim().isEmpty ?? true)) {
    throw CliFailure(
      'Missing $key for $selected. Set it before authoring or use --provider ollama.',
      code: 'provider_not_configured',
      details: {'provider': selected, 'requiredVariable': key},
    );
  }
  final endpoint = environment['FLUVIE_AI_ENDPOINT'];
  if (endpoint != null && endpoint.isNotEmpty) {
    final uri = Uri.tryParse(endpoint);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        !{'http', 'https'}.contains(uri.scheme)) {
      throw const CliFailure(
        'FLUVIE_AI_ENDPOINT must be an absolute HTTP(S) endpoint URL.',
        code: 'invalid_provider_endpoint',
      );
    }
  }
  return selected;
}
