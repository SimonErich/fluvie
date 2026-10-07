import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/captions/caption_source.dart';
import 'package:fluvie/src/core/media/clip_audio.dart';
import 'package:fluvie/src/core/media/generative_source.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/core/media/snapshot_source.dart';
import 'package:fluvie/src/core/time_range.dart';

/// Optional resources for components that introduce media on later frames.
///
/// Ordinary reusable Flutter widgets are discovered by mounting their real
/// element tree. Declare alternatives here only when a frame-dependent builder
/// or asynchronous component cannot expose them during preparation.
final class CompositionResources {
  /// Creates explicit dynamic resource declarations.
  const CompositionResources({
    this.media = const [],
    this.clips = const [],
    this.generative = const [],
    this.snapshots = const [],
    this.shaderAssets = const [],
    this.audio = const [],
    this.captions = const [],
    this.requiresAudioAnalysis = false,
  });

  /// Images that a dynamic component may paint.
  final List<MediaSource> media;

  /// Clips and their actual playback windows.
  final List<ClipResource> clips;

  /// Generated resources a dynamic component may paint.
  final List<GenerativeSource> generative;

  /// External snapshots a dynamic component may paint.
  final List<SnapshotSource> snapshots;

  /// Shaders introduced by a dynamic effect builder.
  final List<String> shaderAssets;

  /// Additional sources read by frame-dependent audio analysis. These declare
  /// preparation, not audible tracks; use Video.audio or Scene.audio for a mix.
  final List<AudioSource> audio;

  /// Caption sources introduced by a frame-dependent overlay.
  final List<CaptionSource> captions;

  /// Set when an audio read or reactive effect is hidden until a later frame.
  /// The composition's declared audio tracks are analysed before frame zero.
  final bool requiresAudioAnalysis;
}

/// A dynamic clip's source, window, trim, speed, and embedded audio policy.
final class ClipResource {
  /// Declares a clip against the enclosing Video or Scene clock.
  const ClipResource({
    required this.source,
    this.window,
    this.trim,
    this.speed = 1,
    this.audio = const ClipAudio.included(),
  });

  /// The video media source.
  final MediaSource source;

  /// Its visible window relative to the declaring Video/Scene.
  final TimeRange? window;

  /// The source-time trim.
  final TimeRange? trim;

  /// Playback rate, including negative visual playback.
  final double speed;

  /// Whether embedded audio participates in the composition.
  final ClipAudio audio;
}
