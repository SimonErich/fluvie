import '../domain/audio_config.dart';

/// Represents an audio source that can be attached to an [AudioTrack].
abstract class AudioSource {
  const AudioSource();

  /// Converts the source into a serializable [AudioSourceConfig].
  AudioSourceConfig toConfig();

  /// Creates an [AudioSource] backed by a Flutter asset.
  factory AudioSource.asset(String assetPath) = _AssetAudioSource;

  /// Creates an [AudioSource] backed by an absolute or relative file path.
  factory AudioSource.file(String filePath) = _FileAudioSource;

  /// Creates an [AudioSource] backed by a remote URL.
  factory AudioSource.url(String url) = _UrlAudioSource;
}

class _AssetAudioSource extends AudioSource {
  final String assetPath;

  const _AssetAudioSource(this.assetPath);

  @override
  AudioSourceConfig toConfig() =>
      AudioSourceConfig(type: AudioSourceType.asset, uri: assetPath);
}

class _FileAudioSource extends AudioSource {
  final String filePath;

  const _FileAudioSource(this.filePath);

  @override
  AudioSourceConfig toConfig() =>
      AudioSourceConfig(type: AudioSourceType.file, uri: filePath);
}

class _UrlAudioSource extends AudioSource {
  final String url;

  const _UrlAudioSource(this.url);

  @override
  AudioSourceConfig toConfig() =>
      AudioSourceConfig(type: AudioSourceType.url, uri: url);
}
