part of 'generative_media_resolver.dart';

extension _GeneratedAssetStorage on GenerativeMediaResolver {
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
