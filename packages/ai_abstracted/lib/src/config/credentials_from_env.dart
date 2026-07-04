import 'package:ai_abstracted/src/config/provider_credentials.dart';
import 'package:ai_abstracted/src/registry/provider_id.dart';

/// Builds [ProviderCredentials] for [provider] from an environment map [env].
///
/// Returns null when the provider's API key is absent. Ollama is keyless, so it
/// always resolves to credentials with an empty [ProviderCredentials.apiKey].
/// Veo authenticates through the Gemini API: it reads `GEMINI_API_KEY`, but a
/// `FLUVIE_VEO_API_KEY` entry overrides it when present.
ProviderCredentials? credentialsFromEnv(ProviderId provider, Map<String, String> env) {
  if (provider == ProviderId.ollama) {
    return const ProviderCredentials(apiKey: '');
  }
  if (provider == ProviderId.veo) {
    final key = env['FLUVIE_VEO_API_KEY'] ?? env['GEMINI_API_KEY'];
    return key == null ? null : ProviderCredentials(apiKey: key);
  }
  final key = env[_envKey(provider)];
  return key == null ? null : ProviderCredentials(apiKey: key);
}

/// Builds credentials for every provider whose key is present in [env].
///
/// Ollama is always included (keyless). Veo is included whenever a Gemini or
/// Veo-override key is present.
Map<ProviderId, ProviderCredentials> allCredentialsFromEnv(Map<String, String> env) {
  final result = <ProviderId, ProviderCredentials>{};
  for (final provider in ProviderId.values) {
    final credentials = credentialsFromEnv(provider, env);
    if (credentials != null) {
      result[provider] = credentials;
    }
  }
  return result;
}

/// The environment variable name that holds [provider]'s API key.
String _envKey(ProviderId provider) {
  switch (provider) {
    case ProviderId.gemini:
    case ProviderId.veo:
      return 'GEMINI_API_KEY';
    case ProviderId.openai:
      return 'OPENAI_API_KEY';
    case ProviderId.flux:
      return 'BFL_API_KEY';
    case ProviderId.elevenLabs:
      return 'ELEVENLABS_API_KEY';
    case ProviderId.suno:
      return 'SUNO_API_KEY';
    case ProviderId.claude:
      return 'ANTHROPIC_API_KEY';
    case ProviderId.mistral:
      return 'MISTRAL_API_KEY';
    // coverage:ignore-start unreachable keyless ollama short circuits before _envKey is ever consulted The case exists only to keep the switch exhaustive
    case ProviderId.ollama:
      return '';
    // coverage:ignore-end
  }
}
