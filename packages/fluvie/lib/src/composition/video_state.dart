// fluvie:large-file-ok: one cohesive Video lifecycle state machine, split from video.dart as a part
part of 'video.dart';

/// `Video`'s internal lifecycle surface — public only so tests can reach it
/// via `tester.state<VideoState>(...)`; everything on it is implementation.
///
/// Owns the composition registrar: the first build collects
/// every element's registration through per-scene [CompositionRegistrarScope]s,
/// a post-frame callback resolves the whole plan exactly once per collect
/// generation, pushes the timeline to an embedder [TimelineProbe],
/// and rebuilds so the fresh per-scene facades notify every element to
/// pick up its injected schedule.
final class VideoState extends State<Video> {
  late VideoRegistrar _registrar;
  late List<GlobalKey> _sceneKeys;
  // The per-collect-generation hero registry: slots register
  // through the per-scene SharedElementScope below, the post-frame resolve
  // validates the set, and a composition change resets it.
  final SharedElementRegistry _sharedElements = SharedElementRegistry();
  ResolvedTimeline? _resolvedTimeline;
  bool _resolveScheduled = false;
  // Set to true after a FluvieTimingError is caught so we don't re-attempt
  // resolution on every build (the registrar stays unresolved after failure).
  bool _timingErrorReported = false;
  // The FluvieTheme.motion layer of the cascade,
  // read from `context.fluvie.motion` in [didChangeDependencies] so a theme
  // above the video feeds the default cascade without touching the Video
  // surface. An unset (all-null) Defaults leaves the cascade byte-identical.
  Defaults _themeMotion = const Defaults();

  /// The timeline of the latest completed resolution, or `null` before the
  /// first post-frame resolve (and after a reset, until the next one).
  @visibleForTesting
  ResolvedTimeline? get resolvedTimeline => _resolvedTimeline;

  @override
  void initState() {
    super.initState();
    _registrar = VideoRegistrar(sceneCount: widget.scenes.length);
    _sceneKeys = _freshSceneKeys(widget.scenes.length);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A FluvieTheme above the video feeds the motion cascade.
    // Reading it here (not in build) establishes the inherited dependency in the
    // right lifecycle hook, and a changed theme motion restarts the collect
    // generation so the next resolve folds the new layer in.
    final motion = context.fluvie.motion;
    if (motion != _themeMotion) {
      _themeMotion = motion;
      if (_registrar.isResolved) {
        _registrar.reset(sceneCount: widget.scenes.length);
        _sharedElements.reset();
        _resolvedTimeline = null;
      }
    }
  }

  @override
  void didUpdateWidget(Video oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different composition restarts the collect generation.
    // fps, the video defaults, and the transition are resolution input too
    // (an overlap reshapes the offsets), so they reset as well; this runs
    // before the subtree updates, so elements see a collecting registrar and
    // rebuild their tokens instead of throwing.
    if (!identical(oldWidget.scenes, widget.scenes) ||
        oldWidget.fps != widget.fps ||
        oldWidget.motionDefaults != widget.motionDefaults ||
        oldWidget.transition != widget.transition) {
      _registrar.reset(sceneCount: widget.scenes.length);
      _sharedElements.reset();
      if (_sceneKeys.length != widget.scenes.length) {
        _sceneKeys = _freshSceneKeys(widget.scenes.length);
      }
      _resolvedTimeline = null;
      _timingErrorReported = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_registrar.isResolved && !_resolveScheduled) {
      _resolveScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback(_resolveSchedules);
    }
    final offsets = widget._offsets;
    return VideoScope(
      fps: widget.fps,
      duration: Time.frames(offsets.totalFrames),
      // The compositor is the only frame reader of the shell: it gates and
      // blends every scene in one shared expanding Stack from the same offset
      // math the getters use. The caption layer sits on top.
      child: _withCaptions(
        TransitionCompositor(
          offsets: offsets,
          transitions: widget._boundaryTransitions,
          sharedElements: _sharedElements,
          sceneShells: [
            for (var s = 0; s < widget.scenes.length; s++)
              _sceneShell(
                widget.scenes[s],
                sceneIndex: s,
                startFrame: offsets.startFrames[s],
              ),
          ],
        ),
      ),
    );
  }

  /// Overlays the caption layer above [composition] when the video declares a
  /// caption track; a track-less video is returned
  /// unchanged, so it mounts no overlay at all.
  Widget _withCaptions(Widget composition) {
    final captions = widget.captions;
    if (captions == null) return composition;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        composition,
        CaptionsLayer(captions: captions),
      ],
    );
  }

  /// One scene's shell: a [GlobalKey]ed subtree (so the registrar's
  /// element tokens survive the compositor reparenting it across boundary
  /// crossings) wrapping the scene's time scope at its running offset, an
  /// optional [CameraLayer] directly under the scope so the scene-wide
  /// move sits outside every element transform but inside the compositor's
  /// blend, the registrar scope its elements register through, and the
  /// per-scene [SharedElementScope] hero slots register through — a fresh
  /// facade per build, so the post-resolution rebuild notifies every element.
  Widget _sceneShell(
    Scene scene, {
    required int sceneIndex,
    required int startFrame,
  }) => KeyedSubtree(
    key: _sceneKeys[sceneIndex],
    child: SceneScope(
      start: Time.frames(startFrame),
      duration: scene.duration,
      child: _withCamera(
        scene.camera,
        child: CompositionRegistrarScope(
          registrar: _registrar.forScene(sceneIndex),
          child: SharedElementScope(
            registry: _sharedElements,
            sceneIndex: sceneIndex,
            child: scene,
          ),
        ),
      ),
    ),
  );

  /// Wraps [child] in a [CameraLayer] when [camera] is non-null; otherwise the
  /// shell mounts no transform at all (a still scene keeps the bare chain).
  Widget _withCamera(Camera? camera, {required Widget child}) =>
      camera == null ? child : CameraLayer(camera: camera, child: child);

  /// A fresh [GlobalKey] per scene; regenerated only when the scene count
  /// changes, so a scene keeps its key (and its mounted state) across rebuilds.
  static List<GlobalKey> _freshSceneKeys(int count) => [
    for (var s = 0; s < count; s++) GlobalKey(debugLabel: 'Video scene $s'),
  ];

  /// The deferred second pass: builds the plan from the
  /// collected registrations, resolves it once, stores the schedules in the
  /// registrar, pushes the timeline to the embedder probe, and
  /// rebuilds so every element picks its schedule up by lookup.
  ///
  /// A [FluvieTimingError] (e.g. `Trigger.beat` with no analysed grid in
  /// preview mode) is caught here and surfaced through the [TimelineProbeScope]
  /// rather than thrown up to the Flutter scheduler, so the inspector can show
  /// a structured error instead of a red debug banner.
  void _resolveSchedules(Duration _) {
    _resolveScheduled = false;
    if (!mounted || _registrar.isResolved || _timingErrorReported) return;
    // The capture shell mounts a BeatGridScope with the analysed grids;
    // threading them into the plan lets `Trigger.beat` resolve
    // without a grid touching the Video surface. No scope leaves the grids
    // null, so the resolver throws the honest "no grid" error for any beat.
    final beatGrids = BeatGridScope.maybeOf(context);
    try {
      final result = buildVideoPlan(
        fps: widget.fps,
        scenes: [
          for (final scene in widget.scenes)
            (duration: scene.duration, defaults: scene.motionDefaults),
        ],
        registrationsByScene: _registrar.registrationsByScene,
        videoDefaults: widget.motionDefaults,
        themeDefaults: _themeMotion,
        boundaryTransitions: widget._boundaryTransitions,
        defaultBeatGrid: beatGrids?.defaultBeatGrid,
        trackBeatGrids: beatGrids?.trackBeatGrids ?? const {},
      );
      _registrar.resolveWith(result.schedules);
      // Validate the hero set against the resolved scene count before any
      // captured frame: a malformed pair throws here, in the
      // pure pre-pass, never mid-capture.
      _sharedElements.validate(widget.scenes.length);
      _resolvedTimeline = result.timeline;
      TimelineProbeScope.maybeOf(context)?.value = result.timeline;
      setState(() {});
    } on FluvieTimingError catch (error) {
      _timingErrorReported = true;
      final probe = TimelineProbeScope.maybeOf(context);
      if (probe != null) {
        // Include anchor names (e.g. "(anchors: music)") by using toString()
        // minus the class-name prefix, which the inspector panel already shows.
        final full = '$error';
        probe.reportError(
          full.startsWith('FluvieTimingError: ') ? full.substring(19) : full,
        );
      } else {
        // No embedder probe: surface through FlutterError so the error is still
        // visible in the debug console and catchable via tester.takeException().
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            library: 'fluvie',
            context: ErrorDescription('resolving the composition timing plan'),
          ),
        );
      }
    }
  }
}
