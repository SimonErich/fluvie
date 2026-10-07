import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fluvie/src/animation/effects/reactive_effect.dart';
import 'package:fluvie/src/animation/motion_target.dart';
import 'package:fluvie/src/animation/runtime/color_lookup_scope.dart';
import 'package:fluvie/src/animation/runtime/effect_stack.dart';
import 'package:fluvie/src/animation/runtime/reactive_scope_builder.dart';
import 'package:fluvie/src/animation/runtime/warm_shader_scope.dart';
import 'package:fluvie/src/captions/runtime/captions_layer.dart';
import 'package:fluvie/src/composition/clip_transition.dart';
import 'package:fluvie/src/composition/composition_resource_scope.dart';
import 'package:fluvie/src/composition/composition_resources.dart';
import 'package:fluvie/src/composition/runtime/clip_plan_collector.dart';
import 'package:fluvie/src/composition/runtime/clip_transition_audio.dart';
import 'package:fluvie/src/composition/runtime/reactive_collector.dart';
import 'package:fluvie/src/composition/runtime/shader_collector.dart';
import 'package:fluvie/src/composition/runtime/spec_element_id.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/composition/transition/shared_element.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/captions/caption_source.dart';
import 'package:fluvie/src/core/contracts/audio_window_resolver.dart';
import 'package:fluvie/src/core/contracts/beat_detection_service.dart';
import 'package:fluvie/src/core/contracts/clip_frame_preparer.dart';
import 'package:fluvie/src/core/contracts/clip_timeline_resolver.dart';
import 'package:fluvie/src/core/contracts/frequency_analyzer.dart';
import 'package:fluvie/src/core/contracts/generative_resolver.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/core/contracts/snapshot_service.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/media/clip_source_kind.dart';
import 'package:fluvie/src/core/media/generative_carrier.dart';
import 'package:fluvie/src/core/media/generative_kind.dart';
import 'package:fluvie/src/core/media/generative_source.dart';
import 'package:fluvie/src/core/media/media_carrier.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/core/media/snapshot_source.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/elements/clip.dart' as fluvie;
import 'package:fluvie/src/elements/generative_media.dart';
import 'package:fluvie/src/elements/runtime/clip_frame_planner.dart';
import 'package:fluvie/src/elements/runtime/clip_painter.dart';
import 'package:fluvie/src/elements/runtime/clip_speed_profile.dart';
import 'package:fluvie/src/elements/snapshot/runtime/snapshot_preparation_boundary.dart';
import 'package:fluvie/src/elements/snapshot/snapshot.dart';
import 'package:fluvie/src/media/runtime/generative_resolver_scope.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';
import 'package:fluvie/src/rendering/capture/capture_shell.dart';
import 'package:fluvie/src/rendering/collect_composition_media.dart';
import 'package:fluvie/src/rendering/no_generative_resolver.dart';
import 'package:fluvie/src/rendering/pre_bake_color_lookups.dart';
import 'package:fluvie/src/rendering/pre_load_shaders.dart';
import 'package:fluvie/src/rendering/preparation_audio_stub.dart'
    if (dart.library.io) 'package:fluvie/src/rendering/preparation_audio_io.dart';
import 'package:fluvie/src/rendering/prepared_composition.dart';
import 'package:fluvie/src/rendering/preview_clip_frames.dart';
import 'package:fluvie/src/rendering/render_cancellation.dart';
import 'package:fluvie/src/rendering/runtime/preparation_scope.dart';
import 'package:fluvie/src/timing/placement/window_resolver.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';

part 'composition_session_discovery.dart';
part 'composition_session_mount.dart';
part 'composition_session_preparation.dart';
part 'composition_session_resources.dart';
part 'composition_session_transitions.dart';
part 'composition_session_validation.dart';

/// Resources discovered by mounting normal Flutter components before frame zero.
///
/// The host owns pumping and resolver lifetime. Discovery visits actual mounted
/// elements; it never invokes a widget's build method itself. Repeat discovery
/// after prepared geometry is published, at most [maximumDiscoveryPasses] times.
// fluvie:large-file-ok: The mounted-session facade keeps its injected host contract and resource state together; lifecycle implementations are in focused parts.
final class CompositionSession {
  /// Creates one preparation generation for an authored composition.
  CompositionSession({
    required this.composition,
    required this.resolver,
    GlobalKey? mountKey,
    this.generative = const NoGenerativeResolver(),
    this.snapshotService,
    this.beatDetector,
    this.analyzer,
    this.loadCubeText = bundleCubeText,
    this.hostFps = 30,
    this.hostFrameCount = 1,
    this.onGenerativeProgress,
    this.clipLookaheadFrames = 0,
    this.cancellation,
  }) : mountKey = mountKey ?? GlobalKey(debugLabel: 'fluvie prepared composition');

  /// A bounded fixed point, independent of the video's number of frames.
  static const maximumDiscoveryPasses = 4;

  /// The authored root.
  final Widget composition;

  /// Resource owner supplied by the host.
  final MediaResolver resolver;

  /// Preserves normal Flutter component state across preparation and playback.
  final GlobalKey mountKey;

  /// Optional generative backend; generation occurs before playback.
  final GenerativeResolver generative;

  /// Optional external snapshot backend.
  final SnapshotService? snapshotService;

  /// Optional audio beat analysis backend.
  final BeatDetectionService? beatDetector;

  /// Optional audio band analysis backend.
  final FrequencyAnalyzer? analyzer;

  /// LUT loader, normally the host's actual asset bundle.
  final CubeTextLoader loadCubeText;

  /// Clock fallback for an arbitrary Flutter composition without a Video root.
  final int hostFps;

  /// Duration fallback for a composition without a Video root.
  final int hostFrameCount;

  /// Progress from the same generative preparation pass as capture.
  final ValueChanged<GenerativeProgress>? onGenerativeProgress;

  /// Sequential source decode-ahead. Zero favors seeks; exports use 15 frames.
  final int clipLookaheadFrames;

  /// Cancellation owner shared with preparation backends and frame capture.
  final RenderCancellation? cancellation;

  Future<T> _run<T>(Future<T> Function() operation) => cancellation?.run(operation) ?? operation();

  final Set<MediaSource> _media = {};
  final Set<MediaSource> _explicitMedia = {};
  final Set<GenerativeSource> _generated = {};
  final Set<GenerativeSource> _preparedGenerated = {};
  final List<({GenerativeMedia widget, TimeScopeData scope})> _generatedVisuals = [];
  final Set<String> _implicitShaders = {};
  final Set<SnapshotSource> _externalSnapshots = {};
  final Map<String, ClipPlan> _clips = {};
  final Map<String, ClipAudioPlan> _clipAudio = {};
  final Set<String> _explicitShaders = {};
  final Set<AudioSource> _additionalAudio = {};
  final Set<CaptionSource> _captions = {};
  final List<Widget> _mountedWidgets = [];
  final List<({ImageProvider<Object> provider, BuildContext context})> _images = [];
  final Set<ImageProvider<Object>> _warmedImages = {};
  final List<Snapshot> _snapshots = [];
  final List<({Snapshot snapshot, GlobalKey targetKey, GlobalKey captureKey, int frame})>
  _snapshotBoundaries = [];
  bool _needsAudioAnalysis = false;
  bool _audioPrepared = false;
  int _passes = 0;
  PreviewClipFrames? _frames;
  Video? _mountedVideo;
  bool _resolvingTiming = false;
  FluvieTimingError? _timingError;
  int _frame = 0;

  /// Whether Fluvie leaves should expose geometry without painting resources.
  bool preparing = true;

  /// Warm shader programs, also shared by preview and capture.
  Map<String, ui.FragmentProgram> shaderPrograms = {};

  /// Baked colour lookups owned by this session.
  Map<String, ui.Image> colorLookups = {};

  /// Reactive track scopes populated only when analysis is required.
  ReactiveTracks reactiveTracks = noReactiveTracks;

  bool _resourcesPrepared = false;

  /// Immutable mounted facts shared by render policy and adapter planning.
  /// Throws until resource and timing preparation has completed.
  PreparedComposition get prepared => _prepared();

  /// The runtime clip windows, including clips hidden inside Flutter builders.
  List<ClipPlan> get clipPlans => List.unmodifiable(_clips.values);

  /// Embedded audio windows discovered from the mounted tree.
  List<ClipAudioPlan> get clipAudioPlans => List.unmodifiable(_clipAudio.values);

  /// All loaded media discovered in this preparation generation.
  Set<MediaSource> get mediaSources => Set.unmodifiable(_media);

  /// In-process snapshots discovered from normal custom widgets.
  List<Snapshot> get snapshots => List.unmodifiable(_snapshots);

  /// Actual mounted snapshot boundaries, retaining their authored layout/clock.
  List<({Snapshot snapshot, GlobalKey targetKey, GlobalKey captureKey, int frame})>
  get snapshotBoundaries => List.unmodifiable(_snapshotBoundaries);

  /// The boundary selected for one rasterization; null restores normal layout.
  GlobalKey? selectedSnapshotBoundary;

  /// Bounded clip frame cache for a preview host.
  PreviewClipFrames? get previewFrames => _frames;

  /// The mounted or transparent-wrapped Video.
  Video? get video => _mountedVideo ?? compositionVideo(composition);

  /// The authored clock, or the host clock for a bare Flutter composition.
  int get fps => video?.fps ?? hostFps;

  /// Runs bounded mounted discovery using the host's actual Flutter pumps.
  /// [beforeReady] can freeze discovered Snapshot subtrees while the original
  /// keyed composition remains mounted. No captured frame is produced here.
  Future<void> prepare({
    required Future<void> Function(Widget tree) mount,
    required Future<void> Function() pump,
    required Widget Function() buildTree,
    required Future<T?> Function<T>(Future<T> Function() callback) runAsync,
    Future<void> Function()? beforeReady,
    bool prepareFirstFrame = true,
    bool activate = true,
    bool warmEffects = true,
    bool prepareSnapshots = true,
  }) => _run(
    () => _prepare(
      mount: mount,
      pump: pump,
      buildTree: buildTree,
      runAsync: runAsync,
      beforeReady: beforeReady,
      prepareFirstFrame: prepareFirstFrame,
      activate: activate,
      warmEffects: warmEffects,
      prepareSnapshots: prepareSnapshots,
    ),
  );

  /// Discovers the normal mounted Flutter element tree.
  bool discover() => _discover();

  /// Prepares synchronous paint lookups before any ready frame.
  Future<void> prepareResources({
    bool decodeImages = true,
    bool warmEffects = true,
    bool prepareSnapshots = true,
  }) => _run(
    () => _prepareResources(
      decodeImages: decodeImages,
      warmEffects: warmEffects,
      prepareSnapshots: prepareSnapshots,
    ),
  );

  /// Warms only source frames required by the requested composition frame.
  Future<void> prepareFrame(int frame) => _run(() => _prepareFrame(frame));

  /// Mounts the same real Flutter subtree in preparation and playback.
  Widget mountTree(Widget child) => _mountTree(child);

  /// Validates ordinary Flutter Image providers before a host captures pixels.
  void validateFrameResources() => _validateFrameResources();

  /// Retires decoded frames only after the host painted their replacements.
  void finishFrame() => _frames?.evict();

  /// Releases only resources owned by the session; the host owns its resolver.
  void dispose() => _dispose();
}
