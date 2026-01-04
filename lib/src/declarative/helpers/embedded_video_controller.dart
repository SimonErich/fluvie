import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show BoxFit;

import '../../domain/audio_config.dart';
import '../../encoding/frame_extraction_service.dart';
import '../../encoding/video_frame_cache.dart';
import '../../encoding/video_probe_service.dart';
import '../../utils/logger.dart';
import '../../utils/video_path_resolver.dart';

/// Controller for EmbeddedVideo widget state and frame extraction.
///
/// Manages video metadata loading, frame extraction coordination,
/// background preloading, and configuration generation for encoding.
///
/// Example:
/// ```dart
/// final controller = EmbeddedVideoController(
///   videoPath: 'assets/video.mp4',
///   startFrame: 30,
///   trimStart: Duration(seconds: 2),
/// );
///
/// await controller.initialize(30);  // composition fps
///
/// // Get frame for display
/// final image = await controller.getFrame(45, 800, 450);
/// ```
class EmbeddedVideoController extends ChangeNotifier {
  /// Path to the video file.
  final String videoPath;

  /// Frame in composition where video starts.
  final int startFrame;

  /// Duration to skip from start of source video.
  final Duration trimStart;

  /// Explicit duration in frames (null = auto-calculate from source).
  final int? durationInFrames;

  /// Whether to include audio from the video.
  final bool includeAudio;

  /// Audio volume (0.0 to 1.0).
  final double audioVolume;

  /// Audio fade-in duration in frames.
  final int audioFadeInFrames;

  /// Audio fade-out duration in frames.
  final int audioFadeOutFrames;

  /// Number of frames to preload ahead.
  final int preloadFrames;

  /// How to fit the video within the display bounds.
  final BoxFit fit;

  // Internal state
  VideoMetadata? _metadata;
  ExtractionState _state = ExtractionState.uninitialized;
  String? _error;
  int? _compositionFps;
  int? _calculatedDuration;
  String? _resolvedVideoPath; // Resolved file system path

  // Services
  final VideoProbeService _probeService;
  final FrameExtractionService _extractionService;
  final VideoFrameCache _cache;
  final VideoPathResolver _pathResolver;

  // Preloading state
  int _lastPreloadFrame = -1;
  Timer? _preloadDebounceTimer;

  // Default display dimensions for preloading (set by first getFrame call or explicit preload)
  int _defaultDisplayWidth = 640;
  int _defaultDisplayHeight = 360;
  bool _initialPreloadStarted = false;

  /// Creates a new EmbeddedVideoController.
  EmbeddedVideoController({
    required this.videoPath,
    this.startFrame = 0,
    this.trimStart = Duration.zero,
    this.durationInFrames,
    this.includeAudio = true,
    this.audioVolume = 1.0,
    this.audioFadeInFrames = 0,
    this.audioFadeOutFrames = 0,
    this.preloadFrames = 30,
    this.fit = BoxFit.cover,
    VideoProbeService? probeService,
    FrameExtractionService? extractionService,
    VideoFrameCache? cache,
    VideoPathResolver? pathResolver,
  })  : _probeService = probeService ?? VideoProbeService(),
        _extractionService = extractionService ?? FrameExtractionService(),
        _cache = cache ?? VideoFrameCacheManager.instance,
        _pathResolver = pathResolver ?? VideoPathResolver();

  /// Current extraction state.
  ExtractionState get state => _state;

  /// Error message if state is [ExtractionState.error].
  String? get error => _error;

  /// Video metadata (null until initialized).
  VideoMetadata? get metadata => _metadata;

  /// Whether the controller is ready to provide frames.
  bool get isReady => _state == ExtractionState.ready;

  /// Calculated duration in composition frames.
  int? get calculatedDurationInFrames => _calculatedDuration;

  /// End frame in composition timeline.
  int get endFrame => startFrame + (_calculatedDuration ?? 0);

  /// Initialize the controller by probing video metadata.
  ///
  /// Must be called before [getFrame] or other operations.
  Future<void> initialize(int compositionFps) async {
    if (_state != ExtractionState.uninitialized) {
      return;
    }

    _compositionFps = compositionFps;
    _state = ExtractionState.loading;
    notifyListeners();

    try {
      // Resolve video path (handles assets, URLs, etc.)
      FluvieLogger.debug('Resolving path: $videoPath', module: 'embedded');
      final resolved = await _pathResolver.resolve(videoPath);
      _resolvedVideoPath = resolved.path;
      FluvieLogger.debug(
        'Resolved to: $_resolvedVideoPath',
        module: 'embedded',
      );

      // Probe video metadata using resolved path
      FluvieLogger.debug('Probing video...', module: 'embedded');
      _metadata = await _probeService.probe(_resolvedVideoPath!);
      FluvieLogger.debug('Metadata: $_metadata', module: 'embedded');

      // Calculate duration in composition frames
      _calculatedDuration = _calculateDuration(compositionFps);
      FluvieLogger.debug(
        'Calculated duration: $_calculatedDuration frames',
        module: 'embedded',
      );

      _state = ExtractionState.ready;
      _error = null;
      FluvieLogger.debug('Ready! endFrame=$endFrame', module: 'embedded');

      // Trigger initial preload of first frames immediately after ready
      // This ensures frames are cached before playback reaches this video
      _scheduleInitialPreload();
    } catch (e, stack) {
      _state = ExtractionState.error;
      _error = e.toString();
      FluvieLogger.error(
        'Initialization failed',
        module: 'embedded',
        error: e,
        stackTrace: stack,
      );
    }

    notifyListeners();
  }

  /// Calculates video duration in composition frames.
  int _calculateDuration(int compositionFps) {
    // Use explicit duration if provided
    if (durationInFrames != null) {
      return durationInFrames!;
    }

    // Auto-calculate from source metadata
    if (_metadata == null) {
      return 0;
    }

    // Available source duration after trim
    final availableDuration = _metadata!.duration - trimStart;
    if (availableDuration.isNegative) {
      return 0;
    }

    // Convert to composition frames (use floor to avoid off-by-one at end)
    return (availableDuration.inMicroseconds * compositionFps / 1000000)
        .floor();
  }

  /// Converts a composition frame to a source video frame.
  ///
  /// Returns -1 if the composition frame is before this video starts.
  int compositionFrameToSourceFrame(int compositionFrame) {
    // Frames since this video started in composition
    final relativeFrame = compositionFrame - startFrame;
    if (relativeFrame < 0) {
      return -1;
    }

    if (_compositionFps == null || _metadata == null) {
      return -1;
    }

    // Time in composition
    final compositionTimeSeconds = relativeFrame / _compositionFps!;

    // Time in source video (accounting for trim)
    final sourceTimeSeconds =
        trimStart.inMicroseconds / 1000000.0 + compositionTimeSeconds;

    // Source frame number
    return (sourceTimeSeconds * _metadata!.fps).round();
  }

  /// Converts a composition frame to source timestamp.
  Duration compositionFrameToSourceTimestamp(int compositionFrame) {
    final relativeFrame = compositionFrame - startFrame;
    if (relativeFrame < 0) {
      return Duration.zero;
    }

    if (_compositionFps == null) {
      return trimStart;
    }

    final compositionTimeSeconds = relativeFrame / _compositionFps!;
    return trimStart +
        Duration(microseconds: (compositionTimeSeconds * 1000000).round());
  }

  /// Checks if a composition frame is within this video's range.
  bool isFrameInRange(int compositionFrame) {
    return compositionFrame >= startFrame && compositionFrame < endFrame;
  }

  /// Gets a frame for display at the given composition frame.
  ///
  /// Returns null if the frame is out of range or not yet loaded.
  /// Starts background preloading if needed.
  Future<ui.Image?> getFrame(
    int compositionFrame,
    int displayWidth,
    int displayHeight,
  ) async {
    if (!isReady || _metadata == null || _resolvedVideoPath == null) {
      return null;
    }

    // Store display dimensions for preloading
    _defaultDisplayWidth = displayWidth;
    _defaultDisplayHeight = displayHeight;

    // Check if frame is in range
    if (!isFrameInRange(compositionFrame)) {
      return null;
    }

    // Calculate source frame (clamped to valid range)
    final sourceFrame = compositionFrameToSourceFrame(compositionFrame);
    if (sourceFrame < 0) {
      return null;
    }
    // Clamp to valid range to handle edge cases
    final clampedSourceFrame = sourceFrame.clamp(0, _metadata!.frameCount - 1);

    // Trigger preloading if needed
    _triggerPreload(compositionFrame, displayWidth, displayHeight);

    try {
      // Get or extract frame using resolved path
      final extractedFrame = await _cache.getOrExtract(
        _extractionService,
        videoPath: _resolvedVideoPath!,
        frameNumber: clampedSourceFrame,
        sourceFps: _metadata!.fps,
        width: displayWidth,
        height: displayHeight,
        fit: fit,
      );

      // Convert to ui.Image
      return await extractedFrame.toImage();
    } catch (e) {
      FluvieLogger.error(
        'Failed to get frame $sourceFrame',
        module: 'embedded',
        error: e,
      );
      return null;
    }
  }

  /// Gets raw frame data for the given composition frame.
  Future<ExtractedFrame?> getFrameRaw(
    int compositionFrame,
    int displayWidth,
    int displayHeight,
  ) async {
    if (!isReady || _metadata == null || _resolvedVideoPath == null) {
      return null;
    }

    if (!isFrameInRange(compositionFrame)) {
      return null;
    }

    final sourceFrame = compositionFrameToSourceFrame(compositionFrame);
    if (sourceFrame < 0 || sourceFrame >= _metadata!.frameCount) {
      return null;
    }

    try {
      return await _cache.getOrExtract(
        _extractionService,
        videoPath: _resolvedVideoPath!,
        frameNumber: sourceFrame,
        sourceFps: _metadata!.fps,
        width: displayWidth,
        height: displayHeight,
        fit: fit,
      );
    } catch (e) {
      FluvieLogger.error(
        'Failed to get raw frame',
        module: 'embedded',
        error: e,
      );
      return null;
    }
  }

  /// Schedules initial preload of first frames after initialization.
  void _scheduleInitialPreload() {
    if (_initialPreloadStarted) return;
    _initialPreloadStarted = true;

    // Schedule preload after a short delay to allow widget to settle
    Timer(const Duration(milliseconds: 50), () {
      _preloadInitialFrames();
    });
  }

  /// Preloads the first N frames of this video.
  ///
  /// Called automatically after initialization to ensure frames are
  /// ready before playback reaches this video's startFrame.
  Future<void> _preloadInitialFrames() async {
    if (!isReady || _metadata == null || _resolvedVideoPath == null) {
      return;
    }

    // Preload first 10 frames (about 1/3 second at 30fps)
    const initialFrameCount = 10;
    final firstSourceFrame = compositionFrameToSourceFrame(startFrame);
    if (firstSourceFrame < 0) {
      return;
    }

    final endSourceFrame = (firstSourceFrame + initialFrameCount - 1).clamp(
      0,
      _metadata!.frameCount - 1,
    );

    FluvieLogger.debug(
      'Initial preload: source frames $firstSourceFrame-$endSourceFrame',
      module: 'embedded',
    );

    _cache.preloadRange(
      _extractionService,
      videoPath: _resolvedVideoPath!,
      startFrame: firstSourceFrame,
      endFrame: endSourceFrame,
      sourceFps: _metadata!.fps,
      width: _defaultDisplayWidth,
      height: _defaultDisplayHeight,
      fit: fit,
    );
  }

  /// Called when playback approaches this video's start frame.
  ///
  /// Triggers aggressive preloading to ensure frames are ready.
  /// Call this when currentFrame is within [lookaheadFrames] of [startFrame].
  void onApproachingStart(int currentFrame, {int lookaheadFrames = 30}) {
    if (!isReady || _metadata == null || _resolvedVideoPath == null) {
      return;
    }

    // Only trigger if we're approaching but not yet at startFrame
    if (currentFrame >= startFrame - lookaheadFrames &&
        currentFrame < startFrame) {
      FluvieLogger.debug(
        'Approaching start (current=$currentFrame, start=$startFrame), triggering preload',
        module: 'embedded',
      );
      _performPreload(startFrame, _defaultDisplayWidth, _defaultDisplayHeight);
    }
  }

  /// Triggers background preloading around the current frame.
  void _triggerPreload(int compositionFrame, int width, int height) {
    // Debounce preloading to avoid excessive calls
    if ((compositionFrame - _lastPreloadFrame).abs() < preloadFrames ~/ 2) {
      return;
    }

    _lastPreloadFrame = compositionFrame;

    // Cancel any pending preload
    _preloadDebounceTimer?.cancel();

    // Schedule preload after a short delay
    _preloadDebounceTimer = Timer(const Duration(milliseconds: 16), () {
      _performPreload(compositionFrame, width, height);
    });
  }

  /// Performs background preloading.
  Future<void> _performPreload(
    int compositionFrame,
    int width,
    int height,
  ) async {
    if (!isReady || _metadata == null || _resolvedVideoPath == null) {
      return;
    }

    // Calculate source frame range to preload
    final startSourceFrame = compositionFrameToSourceFrame(compositionFrame);
    if (startSourceFrame < 0) {
      return;
    }

    // Calculate end frame (accounting for composition duration)
    final preloadEndComposition = compositionFrame + preloadFrames;
    final endSourceFrame = compositionFrameToSourceFrame(
      preloadEndComposition.clamp(startFrame, endFrame - 1),
    );

    if (endSourceFrame <= startSourceFrame) {
      return;
    }

    // Use range extraction for efficiency (with resolved path)
    _cache.preloadRange(
      _extractionService,
      videoPath: _resolvedVideoPath!,
      startFrame: startSourceFrame,
      endFrame: endSourceFrame.clamp(0, _metadata!.frameCount - 1),
      sourceFps: _metadata!.fps,
      width: width,
      height: height,
      fit: fit,
    );
  }

  /// Generates audio configuration for the final encoding.
  ///
  /// Returns null if [includeAudio] is false or video has no audio.
  AudioTrackConfig? toAudioConfig() {
    if (!includeAudio || _metadata == null || !_metadata!.hasAudio) {
      return null;
    }

    if (_compositionFps == null || _calculatedDuration == null) {
      return null;
    }

    // Convert trim to frames
    final trimFrames =
        (trimStart.inMicroseconds * _compositionFps! / 1000000).round();

    // Determine source type based on path format
    final AudioSourceType sourceType;
    if (videoPath.startsWith('http://') || videoPath.startsWith('https://')) {
      sourceType = AudioSourceType.url;
    } else if (videoPath.startsWith('assets/') ||
        videoPath.startsWith('packages/')) {
      sourceType = AudioSourceType.asset;
    } else {
      sourceType = AudioSourceType.file;
    }

    return AudioTrackConfig(
      source: AudioSourceConfig(type: sourceType, uri: videoPath),
      startFrame: startFrame,
      durationInFrames: _calculatedDuration!,
      trimStartFrame: trimFrames,
      volume: audioVolume,
      fadeInFrames: audioFadeInFrames,
      fadeOutFrames: audioFadeOutFrames,
    );
  }

  /// Clears cached frames for this video.
  void clearCache() {
    if (_resolvedVideoPath != null) {
      _cache.clearVideo(_resolvedVideoPath!);
    }
  }

  @override
  void dispose() {
    _preloadDebounceTimer?.cancel();
    clearCache();
    super.dispose();
  }
}

/// Extraction state for EmbeddedVideoController.
enum ExtractionState {
  /// Controller not yet initialized.
  uninitialized,

  /// Loading video metadata.
  loading,

  /// Ready to extract frames.
  ready,

  /// Error occurred during initialization.
  error,
}
