import 'package:meta/meta.dart';

/// Credentials and connection settings for a single provider.
@immutable
class ProviderCredentials {
  /// Creates [ProviderCredentials] authenticating with [apiKey].
  const ProviderCredentials({
    required this.apiKey,
    this.baseUrl,
    this.organization,
    this.project,
    this.extra = const {},
  });

  /// The provider API key. May be empty for keyless providers (such as Ollama).
  final String apiKey;

  /// An optional base URL override (for self-hosted or proxied endpoints).
  final Uri? baseUrl;

  /// An optional organization id, for providers that scope by organization.
  final String? organization;

  /// An optional project id, for providers that scope by project.
  final String? project;

  /// Any extra provider-specific settings, passed through verbatim.
  final Map<String, String> extra;
}
