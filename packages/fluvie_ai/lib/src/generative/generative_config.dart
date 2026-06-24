import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:meta/meta.dart';

/// Configuration for the generative media resolver: provider [credentials], the
/// on-disk [cacheDir], an [offline] switch, and an optional [maxGenerations]
/// budget.
///
/// Build it explicitly (server, on-device secure storage, tests) or from the
/// environment with [GenerativeConfig.fromEnv]. Credentials are never logged or
/// committed; the [cacheDir] holds the produced assets, keyed by prompt + seed +
/// params, and is safe to commit so CI and teammates reuse them.
@immutable
class GenerativeConfig {
  /// Creates a config over [credentials], an optional [cacheDir] (defaults to
  /// `.fluvie/generative` under the working directory), an [offline] switch, and
  /// an optional [maxGenerations] budget per render.
  const GenerativeConfig({
    this.credentials = const {},
    this.cacheDir,
    this.offline = false,
    this.maxGenerations,
  });

  /// Reads provider API keys and settings from [env].
  ///
  /// Keys come from each provider's variable (for example `GEMINI_API_KEY`,
  /// `OPENAI_API_KEY`, `BFL_API_KEY`, `ELEVENLABS_API_KEY`, `SUNO_API_KEY`);
  /// `FLUVIE_GENERATIVE_CACHE_DIR` overrides the cache directory and
  /// `FLUVIE_GENERATIVE_OFFLINE` (`1`/`true`) forces cache-only resolution.
  factory GenerativeConfig.fromEnv(Map<String, String> env) => GenerativeConfig(
    credentials: allCredentialsFromEnv(env),
    cacheDir: env['FLUVIE_GENERATIVE_CACHE_DIR'],
    offline: _truthy(env['FLUVIE_GENERATIVE_OFFLINE']),
  );

  /// The API credentials per provider.
  final Map<ProviderId, ProviderCredentials> credentials;

  /// Where produced assets are cached, or `null` for the default.
  final String? cacheDir;

  /// When `true`, only cached assets are served; a miss is an error (so CI never
  /// silently calls a paid API).
  final bool offline;

  /// The most assets a single render may generate (cache hits do not count), or
  /// `null` for no limit.
  final int? maxGenerations;

  static bool _truthy(String? value) => value == '1' || value == 'true';
}
