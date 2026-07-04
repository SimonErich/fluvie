import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie_ai/src/generative/generative_cache.dart';
import 'package:fluvie_ai/src/generative/generative_config.dart';
import 'package:fluvie_ai/src/generative/generative_providers.dart';
import 'package:http/http.dart' as http;

/// Produces one generative asset, injected so the resolver is testable without a
/// network (tests pass a function returning a canned [GenerationResult]).
typedef GenerateFn = Future<GenerationResult> Function(GenerativeSource source);

/// The real [GenerativeResolver]: produces every declared generative source
/// through ai_abstracted before the frame loop, caches it on disk by prompt +
/// seed + params, and serves the produced file-backed source synchronously.
///
/// Install it with `fluvieGenerativeResolver` (or pass it to a render). It is
/// idempotent and honors the config's offline switch and generation budget.
final class GenerativeMediaResolver implements GenerativeResolver {
  /// Creates a resolver over [config]. [cache], [registry], [httpClient], and
  /// [generate] are injectable; by default it caches under the config dir and
  /// calls ai_abstracted through a [ProviderRegistry].
  GenerativeMediaResolver({
    required GenerativeConfig config,
    GenerativeCache? cache,
    ProviderRegistry registry = const ProviderRegistry(),
    http.Client? httpClient,
    GenerateFn? generate,
  }) : _config = config,
       _cache = cache ?? GenerativeCache(config.cacheDir ?? defaultGenerativeCacheDir()),
       _generate =
           generate ??
           ((source) => generateFor(
             source,
             registry: registry,
             credentials: _requireCredentials(config, source),
             httpClient: httpClient,
           ));

  /// Builds a resolver reading credentials and settings from [env].
  factory GenerativeMediaResolver.fromEnv(Map<String, String> env, {http.Client? httpClient}) =>
      GenerativeMediaResolver(config: GenerativeConfig.fromEnv(env), httpClient: httpClient);

  final GenerativeConfig _config;
  final GenerativeCache _cache;
  final GenerateFn _generate;

  final Map<GenerativeSource, MediaSource> _media = {};
  final Map<GenerativeSource, AudioSource> _audio = {};
  final Map<GenerativeSource, GeneratedAssetMeta> _meta = {};

  @override
  Future<void> generateAll(
    Iterable<GenerativeSource> sources, {
    void Function(GenerativeProgress progress)? onProgress,
  }) async {
    final list = sources.toList();
    var generated = 0;
    for (var i = 0; i < list.length; i++) {
      final source = list[i];
      if (_meta.containsKey(source)) continue;
      final key = source.cacheKey;
      if (_cache.has(source.providerId, key)) {
        _loadFromCache(source, key);
        _report(onProgress, i, list.length, source, 'cached');
        continue;
      }
      if (_config.offline) {
        throw FluvieGenerativeException(
          'Offline: no cached asset for $source. Pre-warm the cache (run once '
          'online and commit .fluvie/generative) or unset FLUVIE_GENERATIVE_OFFLINE.',
        );
      }
      final budget = _config.maxGenerations;
      if (budget != null && generated >= budget) {
        throw FluvieGenerativeException(
          'Generation budget ($budget) exceeded while resolving $source.',
        );
      }
      _report(onProgress, i, list.length, source, 'generating');
      await _storeProduced(source, key, await _runGenerate(source));
      generated++;
      _report(onProgress, i, list.length, source, 'done');
    }
  }

  Future<GenerationResult> _runGenerate(GenerativeSource source) async {
    try {
      return await _generate(source);
    } on AiException catch (error) {
      throw FluvieGenerativeException(
        'Generation failed for $source via ${source.providerId}: ${error.message}',
      );
    }
  }

  Future<void> _storeProduced(GenerativeSource source, String key, GenerationResult result) async {
    final ext = _extFor(result.mimeType, result.kind);
    await _cache.write(
      providerId: source.providerId,
      cacheKey: key,
      ext: ext,
      bytes: result.bytes,
      sidecar: {
        'provider': source.providerId,
        'model': result.metadata.model,
        'prompt': source.prompt,
        'seed': source.seed,
        'params': source.params,
        'mimeType': result.mimeType,
        'ext': ext,
        'durationMs': result.metadata.durationMs,
        'hasAudio': result.metadata.hasAudio,
        'width': result.metadata.width,
        'height': result.metadata.height,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      },
    );
    _register(source, _cache.assetFile(source.providerId, key, ext).path, (
      duration: _duration(result.metadata.durationMs),
      hasAudio: result.metadata.hasAudio,
      width: result.metadata.width,
      height: result.metadata.height,
    ));
  }

  void _loadFromCache(GenerativeSource source, String key) {
    final sidecar = _cache.readSidecar(source.providerId, key);
    final ext = sidecar['ext'] as String? ?? (source.isAudio ? 'mp3' : 'png');
    _register(source, _cache.assetFile(source.providerId, key, ext).path, (
      duration: _duration(_asInt(sidecar['durationMs'])),
      hasAudio: sidecar['hasAudio'] as bool? ?? false,
      width: _asInt(sidecar['width']),
      height: _asInt(sidecar['height']),
    ));
  }

  void _register(GenerativeSource source, String path, GeneratedAssetMeta meta) {
    if (source.isAudio) {
      _audio[source] = AudioSource.file(path);
    } else {
      _media[source] = MediaSource.file(path);
    }
    _meta[source] = meta;
  }

  @override
  MediaSource mediaFor(GenerativeSource source) => _media[source] ?? (throw _unresolved(source));

  @override
  AudioSource audioFor(GenerativeSource source) => _audio[source] ?? (throw _unresolved(source));

  @override
  GeneratedAssetMeta metaFor(GenerativeSource source) =>
      _meta[source] ?? (throw _unresolved(source));

  FluvieGenerativeException _unresolved(GenerativeSource source) => FluvieGenerativeException(
    'No produced asset for $source. The generative pre-pass (generateAll) must '
    'run before the frame loop.',
  );

  void _report(
    void Function(GenerativeProgress)? onProgress,
    int index,
    int total,
    GenerativeSource source,
    String stage,
  ) => onProgress?.call((
    index: index,
    total: total,
    providerId: source.providerId,
    stage: stage,
  ));

  static ProviderCredentials _requireCredentials(GenerativeConfig config, GenerativeSource source) {
    final credentials = config.credentials[providerIdFor(source.providerId)];
    if (credentials == null) {
      throw FluvieGenerativeException(
        'No API credentials for provider "${source.providerId}". Set its API key '
        '(an environment variable or an explicit GenerativeConfig).',
      );
    }
    return credentials;
  }
}

Duration? _duration(int? ms) => ms == null ? null : Duration(milliseconds: ms);

int? _asInt(Object? value) => value is int ? value : (value is num ? value.toInt() : null);

String _extFor(String mimeType, MediaKind kind) => switch (mimeType) {
  'image/png' => 'png',
  'image/jpeg' || 'image/jpg' => 'jpg',
  'image/webp' => 'webp',
  'video/mp4' => 'mp4',
  'video/webm' => 'webm',
  'audio/mpeg' || 'audio/mp3' => 'mp3',
  'audio/wav' || 'audio/x-wav' => 'wav',
  'audio/ogg' => 'ogg',
  _ => switch (kind) {
    MediaKind.image => 'png',
    MediaKind.video => 'mp4',
    _ => 'mp3',
  },
};
