part of 'server_config.dart';

/// The AI env vars passed through to the render project (when present).
const _aiEnvKeys = [
  'FLUVIE_AI_PROVIDER',
  'FLUVIE_AI_MODEL',
  'ANTHROPIC_API_KEY',
  'GEMINI_API_KEY',
  'MISTRAL_API_KEY',
];

/// Parses a [ServerConfig] from [env] (typically `Platform.environment`).
///
/// Pure and unit-testable; throws a [ServerConfigException] on any missing or
/// malformed value rather than silently defaulting a secret. Mirrors the
/// `aiClientFromEnv` pattern in `fluvie_ai`.
ServerConfig serverConfigFromEnvironment(Map<String, String> env) {
  final port = _int(env, 'PORT', 8080);
  final apiToken = _required(env, 'API_TOKEN');
  final backend = _enum(env, 'STORAGE_BACKEND', StorageBackend.values, StorageBackend.local);
  final signingKey = trimToNull(env['DOWNLOAD_SIGNING_KEY']);
  return ServerConfig(
    host: env['HOST'] ?? '0.0.0.0',
    port: port,
    publicBaseUrl: Uri.parse(env['PUBLIC_BASE_URL'] ?? 'http://localhost:$port'),
    apiToken: apiToken,
    cleanupToken: _required(env, 'CLEANUP_TOKEN'),
    downloadSigningKey: signingKey != null
        ? utf8.encode(signingKey)
        : sha256.convert(utf8.encode('fluvie-download:$apiToken')).bytes,
    storageBackend: backend,
    localStorageDir: env['LOCAL_STORAGE_DIR'] ?? '/data/renders',
    s3: backend == StorageBackend.s3 ? _s3(env) : null,
    publicByDefault: _bool(env, 'PUBLIC_BY_DEFAULT', fallback: false),
    fileTtl: _duration(env, 'FILE_TTL', const Duration(hours: 24)),
    downloadUrlTtl: _duration(env, 'DOWNLOAD_URL_TTL', const Duration(minutes: 15)),
    cleanupInterval: _duration(env, 'CLEANUP_INTERVAL', const Duration(hours: 1)),
    renderConcurrency: _int(env, 'RENDER_CONCURRENCY', 1),
    renderProject: trimToNull(env['RENDER_PROJECT']),
    ffmpegPath: trimToNull(env['FFMPEG_PATH']),
    corsAllowOrigins: (env['CORS_ALLOW_ORIGINS'] ?? '')
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(),
    aiEnv: {
      for (final key in _aiEnvKeys)
        if (trimToNull(env[key]) != null) key: env[key]!,
    },
    aiRateLimit: RateLimitConfig(
      limit: _int(env, 'FLUVIE_AI_RATE_LIMIT', RateLimitConfig.defaults.limit),
      window: _duration(env, 'FLUVIE_AI_RATE_WINDOW', RateLimitConfig.defaults.window),
      dailyQuota: _int(env, 'FLUVIE_AI_DAILY_QUOTA', RateLimitConfig.defaults.dailyQuota),
    ),
  );
}

S3Config _s3(Map<String, String> env) => S3Config(
  endpoint: _required(env, 'S3_ENDPOINT'),
  region: env['S3_REGION'] ?? 'us-east-1',
  bucket: _required(env, 'S3_BUCKET'),
  accessKey: _required(env, 'S3_ACCESS_KEY'),
  secretKey: _required(env, 'S3_SECRET_KEY'),
  useSsl: _bool(env, 'S3_USE_SSL', fallback: true),
  pathStyle: _bool(env, 'S3_PATH_STYLE', fallback: false),
  publicBaseUrl: trimToNull(env['S3_PUBLIC_BASE']) == null
      ? null
      : Uri.parse(env['S3_PUBLIC_BASE']!),
);

String _required(Map<String, String> env, String key) {
  final value = trimToNull(env[key]);
  if (value == null) throw ServerConfigException('$key is required');
  return value;
}

int _int(Map<String, String> env, String key, int fallback) {
  final raw = trimToNull(env[key]);
  if (raw == null) return fallback;
  final value = int.tryParse(raw);
  if (value == null || value < 0) throw ServerConfigException('$key must be a non-negative int');
  return value;
}

bool _bool(Map<String, String> env, String key, {required bool fallback}) {
  final raw = trimToNull(env[key])?.toLowerCase();
  if (raw == null) return fallback;
  if (raw == 'true') return true;
  if (raw == 'false') return false;
  throw ServerConfigException('$key must be true or false');
}

Duration _duration(Map<String, String> env, String key, Duration fallback) {
  final raw = trimToNull(env[key]);
  if (raw == null) return fallback;
  try {
    return parseHumanDuration(raw, label: key);
  } on FormatException catch (error) {
    throw ServerConfigException(error.message);
  }
}

T _enum<T extends Enum>(Map<String, String> env, String key, List<T> values, T fallback) {
  final raw = trimToNull(env[key]);
  if (raw == null) return fallback;
  for (final value in values) {
    if (value.name == raw) return value;
  }
  throw ServerConfigException('$key must be one of ${values.map((v) => v.name).join(', ')}');
}
