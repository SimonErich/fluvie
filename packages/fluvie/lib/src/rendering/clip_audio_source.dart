import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/media/media_source.dart';

/// The [AudioSource] the encoder extracts a clip's embedded audio from: the
/// clip's own video. FFmpeg reads `[N:a]` from a `-i video.mp4` input just as
/// it would from an audio file, so a clip's track needs no separate audio
/// asset.
///
/// A memory clip carries its bytes as an [AudioSource.memory], so the audio
/// pre-pass materializes them to the same kind of temp file the frame pre-pass
/// already writes — an imported browser file mixes like a file on disk. Pure
/// and platform-free: the desktop staging and the encoder-neutral
/// `resolveAudioMix` both derive a clip's audio input here.
AudioSource clipAudioSourceFor(MediaSource source) => switch (source) {
  FileSource(:final path) => AudioSource.file(path),
  AssetSource(:final name) => AudioSource.asset(name),
  NetworkSource(:final url) => AudioSource.network(url),
  MemorySource(:final bytes, :final debugLabel) => AudioSource.memory(
    bytes,
    debugLabel: debugLabel,
  ),
};
