import 'package:json_annotation/json_annotation.dart';

part 'audio_config.g.dart';

/// Configuration model that represents an audio track within a composition.
@JsonSerializable(explicitToJson: true)
class AudioTrackConfig {
  /// Where the audio comes from (asset/file/url).
  final AudioSourceConfig source;

  /// The frame in the video timeline where this audio clip should start.
  final int startFrame;

  /// How many frames the audio should play for.
  final int durationInFrames;

  /// Trim offset at the beginning of the source audio, in frames.
  ///
  /// Use [trimStartFrameToMs] to convert to milliseconds for FFmpeg.
  final int trimStartFrame;

  /// Optional trim offset at the end of the source audio, in frames.
  ///
  /// Use [trimEndFrameToMs] to convert to milliseconds for FFmpeg.
  final int? trimEndFrame;

  /// Playback volume multiplier (1.0 = original volume).
  final double volume;

  /// Frames used to fade-in from silence.
  final int fadeInFrames;

  /// Frames used to fade-out to silence.
  final int fadeOutFrames;

  /// Whether the audio should loop if shorter than [durationInFrames].
  final bool loop;

  /// Optional sync configuration for timing this audio to visual elements.
  ///
  /// When set, the [startFrame] and [durationInFrames] may be resolved
  /// from SyncAnchor elements during render.
  final AudioSyncConfig? sync;

  const AudioTrackConfig({
    required this.source,
    required this.startFrame,
    required this.durationInFrames,
    this.trimStartFrame = 0,
    this.trimEndFrame,
    this.volume = 1.0,
    this.fadeInFrames = 0,
    this.fadeOutFrames = 0,
    this.loop = false,
    this.sync,
  });

  /// Converts [trimStartFrame] to milliseconds for a given FPS.
  int trimStartFrameToMs(int fps) => framesToMs(trimStartFrame, fps);

  /// Converts [trimEndFrame] to milliseconds for a given FPS.
  int? trimEndFrameToMs(int fps) =>
      trimEndFrame != null ? framesToMs(trimEndFrame!, fps) : null;

  /// Resolves sync references using the provided anchor map.
  ///
  /// Returns a new [AudioTrackConfig] with [startFrame] and [durationInFrames]
  /// calculated from the referenced anchors. If no sync config exists or the
  /// referenced anchors are not found, returns this config unchanged.
  ///
  /// The [anchors] map should contain anchor IDs as keys and their timing info
  /// (start frame, end frame) as values.
  AudioTrackConfig resolveSync(
    Map<String, ({int startFrame, int? endFrame})> anchors,
  ) {
    if (sync == null || !sync!.hasSyncConfig) {
      return this;
    }

    int resolvedStartFrame = startFrame;
    int resolvedDurationInFrames = durationInFrames;
    bool shouldLoop = loop;

    // Resolve start frame from anchor
    if (sync!.syncStartWithAnchor != null) {
      final anchor = anchors[sync!.syncStartWithAnchor];
      if (anchor != null) {
        resolvedStartFrame = anchor.startFrame + sync!.startOffset;
      }
    }

    // Resolve end frame from anchor
    if (sync!.syncEndWithAnchor != null) {
      final anchor = anchors[sync!.syncEndWithAnchor];
      if (anchor != null && anchor.endFrame != null) {
        final resolvedEndFrame = anchor.endFrame! + sync!.endOffset;
        resolvedDurationInFrames = resolvedEndFrame - resolvedStartFrame;

        // Apply sync behavior
        if (sync!.behavior == SyncBehavior.loopToMatch) {
          shouldLoop = true;
        }
      }
    }

    return copyWith(
      startFrame: resolvedStartFrame,
      durationInFrames: resolvedDurationInFrames,
      loop: shouldLoop,
      sync: null, // Clear sync after resolution
    );
  }

  /// Creates a copy with the specified fields replaced.
  AudioTrackConfig copyWith({
    AudioSourceConfig? source,
    int? startFrame,
    int? durationInFrames,
    int? trimStartFrame,
    int? trimEndFrame,
    double? volume,
    int? fadeInFrames,
    int? fadeOutFrames,
    bool? loop,
    AudioSyncConfig? sync,
  }) {
    return AudioTrackConfig(
      source: source ?? this.source,
      startFrame: startFrame ?? this.startFrame,
      durationInFrames: durationInFrames ?? this.durationInFrames,
      trimStartFrame: trimStartFrame ?? this.trimStartFrame,
      trimEndFrame: trimEndFrame ?? this.trimEndFrame,
      volume: volume ?? this.volume,
      fadeInFrames: fadeInFrames ?? this.fadeInFrames,
      fadeOutFrames: fadeOutFrames ?? this.fadeOutFrames,
      loop: loop ?? this.loop,
      sync: sync,
    );
  }

  factory AudioTrackConfig.fromJson(Map<String, dynamic> json) =>
      _$AudioTrackConfigFromJson(json);

  Map<String, dynamic> toJson() => _$AudioTrackConfigToJson(this);
}

/// Converts frames to milliseconds.
int framesToMs(int frames, int fps) => (frames * 1000 / fps).round();

/// Converts milliseconds to frames.
int msToFrames(int ms, int fps) => (ms * fps / 1000).round();

/// Defines where an audio file should be loaded from.
@JsonSerializable()
class AudioSourceConfig {
  /// Type of audio source.
  final AudioSourceType type;

  /// Asset name, file path, or URL depending on [type].
  final String uri;

  const AudioSourceConfig({required this.type, required this.uri});

  factory AudioSourceConfig.fromJson(Map<String, dynamic> json) =>
      _$AudioSourceConfigFromJson(json);

  Map<String, dynamic> toJson() => _$AudioSourceConfigToJson(this);
}

/// Enumerates audio source types supported by the engine.
@JsonEnum(fieldRename: FieldRename.snake)
enum AudioSourceType { asset, file, url }

/// Defines how audio should behave when synced to a visual element.
@JsonEnum(fieldRename: FieldRename.snake)
enum SyncBehavior {
  /// Audio stops when it reaches its natural end, regardless of synced element.
  stopWhenEnds,

  /// Audio loops to match the duration of the synced element.
  loopToMatch,
}

/// Configuration for syncing audio to visual elements via SyncAnchor.
@JsonSerializable()
class AudioSyncConfig {
  /// The anchor ID to sync the start frame with.
  ///
  /// If set, [startFrame] will be resolved from this anchor.
  final String? syncStartWithAnchor;

  /// The anchor ID to sync the end frame with.
  ///
  /// If set, [durationInFrames] will be calculated from this anchor's end.
  final String? syncEndWithAnchor;

  /// Offset applied to the start sync point.
  ///
  /// Positive values delay the start, negative values anticipate it.
  final int startOffset;

  /// Offset applied to the end sync point.
  ///
  /// Positive values extend past the anchor end, negative values cut early.
  final int endOffset;

  /// How the audio should behave when synced.
  final SyncBehavior behavior;

  const AudioSyncConfig({
    this.syncStartWithAnchor,
    this.syncEndWithAnchor,
    this.startOffset = 0,
    this.endOffset = 0,
    this.behavior = SyncBehavior.stopWhenEnds,
  });

  /// Whether this config has any sync references.
  bool get hasSyncConfig =>
      syncStartWithAnchor != null || syncEndWithAnchor != null;

  factory AudioSyncConfig.fromJson(Map<String, dynamic> json) =>
      _$AudioSyncConfigFromJson(json);

  Map<String, dynamic> toJson() => _$AudioSyncConfigToJson(this);
}
