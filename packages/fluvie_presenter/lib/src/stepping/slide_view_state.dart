part of 'slide_view.dart';

/// One mounted slide: its stretched composition, its clock, and its stop
/// states — everything a stage needs to render, kept so an outgoing slide
/// can hold during a blend.
final class _MountedSlide {
  _MountedSlide({required this.video, required this.clock, required this.states});

  final Video video;
  final LivePlaybackController clock;
  final Map<Stop, StopState> states;

  void dispose() => clock.dispose();
}

final class _SlideViewState extends ConsumerState<SlideView> with TickerProviderStateMixin {
  late List<SlidePlan> _plans;
  late PresentationPosition _position;
  late _MountedSlide _current;
  _MountedSlide? _outgoing;
  AnimationController? _blend;
  Transition? _transition;

  @override
  void initState() {
    super.initState();
    _plans = ref.read(slidePlansProvider);
    _position = ref.read(presentationControllerProvider).position;
    _current = _mount(_position);
    ref.listenManual(presentationControllerProvider, _onState);
  }

  @override
  void dispose() {
    _clearBlend();
    _current.dispose();
    super.dispose();
  }

  /// Mounts the slide at [position] with steps up to `position.step`
  /// settled — the held state slide entries and jumps land on. A fresh
  /// clock starts at frame zero, so the base content plays its entrance
  /// either way.
  _MountedSlide _mount(PresentationPosition position) {
    final plan = _plans[position.slide];
    final clock =
        widget.clockFactory?.call(widget.video.fps) ??
        (LivePlaybackController(fps: widget.video.fps)..play());
    final states = <Stop, StopState>{};
    for (var k = 1; k < plan.stepCount; k++) {
      final step = plan.steps[k];
      for (final stop in step.stops) {
        states[stop] = k <= position.step
            ? RevealedStop(baseFrame: clock.frame, skipFrames: step.entranceFrames)
            : const HiddenStop();
      }
    }
    return _MountedSlide(
      video: Video(
        width: widget.video.width,
        height: widget.video.height,
        fps: widget.video.fps,
        motionDefaults: widget.video.motionDefaults,
        scenes: [stretchSceneForSlide(widget.video.scenes[plan.sceneIndex])],
      ),
      clock: clock,
      states: states,
    );
  }

  void _onState(PresentationState? previous, PresentationState next) {
    if (next.position == _position) return;
    setState(() {
      if (next.position.slide == _position.slide) {
        _updateSteps(next.position, next.lastMove);
      } else {
        _switchSlide(next.position, next.lastMove);
      }
      _position = next.position;
    });
  }

  /// Applies a step change within the mounted slide. Already-revealed steps
  /// keep their state (their ambient phase survives); a forward advance
  /// reveals its target step with the entrance playing, everything else
  /// settles or hides.
  void _updateSteps(PresentationPosition position, NavigationKind kind) {
    final plan = _plans[position.slide];
    for (var k = 1; k < plan.stepCount; k++) {
      final step = plan.steps[k];
      for (final stop in step.stops) {
        if (k > position.step) {
          _current.states[stop] = const HiddenStop();
        } else if (_current.states[stop] is! RevealedStop) {
          final reveals = kind == NavigationKind.forward && k == position.step;
          _current.states[stop] = RevealedStop(
            baseFrame: _current.clock.frame,
            skipFrames: reveals ? 0 : step.entranceFrames,
          );
        }
      }
    }
  }

  /// Swaps to another slide: a forward move onto the next slide plays the
  /// authored boundary transition (unless transitions are off); every other
  /// move cuts to the settled target.
  void _switchSlide(PresentationPosition position, NavigationKind kind) {
    final authored = _boundaryTransition(position);
    final blends =
        widget.playTransitions &&
        kind == NavigationKind.forward &&
        position.slide == _position.slide + 1 &&
        authored != null &&
        authored.kind != TransitionKind.cut;
    _clearBlend();
    if (!blends) {
      _current.dispose();
      _current = _mount(position);
      return;
    }
    _outgoing = _current..clock.pause();
    _current = _mount(position);
    _transition = authored;
    final frames = authored.duration.resolveFrames(_PresenterTimeScope(widget.video.fps));
    final blend = AnimationController(
      vsync: this,
      duration: Duration(microseconds: (frames * 1e6 / widget.video.fps).round()),
    )..addStatusListener(_onBlendStatus);
    // The TickerFuture resolves when the blend completes; the status
    // listener owns that moment, so nothing awaits it.
    unawaited(blend.forward());
    _blend = blend;
  }

  void _onBlendStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    // Disposing the controller from inside its own notification is illegal;
    // finish the swap on the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(_clearBlend);
    });
  }

  void _clearBlend() {
    _blend?.dispose();
    _blend = null;
    _outgoing?.dispose();
    _outgoing = null;
    _transition = null;
  }

  /// The authored transition governing the boundary into `position.slide`:
  /// the incoming scene's enter beats the outgoing scene's exit beats the
  /// video default — the compositor's own precedence, mirrored.
  Transition? _boundaryTransition(PresentationPosition position) {
    final incoming = widget.video.scenes[_plans[position.slide].sceneIndex];
    final outgoing = widget.video.scenes[_plans[_position.slide].sceneIndex];
    return incoming.enter ?? outgoing.exit ?? widget.video.transition;
  }

  Widget _stage(_MountedSlide slide) => StepScope(
    states: Map.of(slide.states),
    child: LivePlayer(
      controller: slide.clock,
      child: FittedBox(
        child: SizedBox(
          width: widget.video.width.toDouble(),
          height: widget.video.height.toDouble(),
          child: slide.video,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final outgoing = _outgoing;
    final blend = _blend;
    final transition = _transition;
    final current = _stage(_current);
    if (outgoing == null || blend == null || transition == null) return current;
    return SlideTransitionBlend(
      transition: transition,
      progress: blend,
      outgoing: _stage(outgoing),
      incoming: current,
    );
  }
}
