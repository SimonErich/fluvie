part of 'composition_session.dart';

extension _MountedDiscovery on CompositionSession {
  /// Visits the actual mounted composition, returning whether resources changed.
  bool _discover() {
    if (++_passes > CompositionSession.maximumDiscoveryPasses) {
      throw FluvieRenderException(
        'Composition resources did not stabilize after '
        '${CompositionSession.maximumDiscoveryPasses} preparation passes. Keep build deterministic; '
        'declare frame-dependent alternatives with Video.resources or Scene.resources.',
      );
    }
    final before = _fingerprint;
    _mountedWidgets.clear();
    _images.clear();
    _snapshots.clear();
    _snapshotBoundaries.clear();
    _generatedVisuals.clear();
    final root = mountKey.currentContext;
    if (root == null) {
      throw StateError('Mount session.mountTree(...) before discovering resources.');
    }
    void visit(Element element) {
      final widget = element.widget;
      if (widget is Video) _mountedVideo = widget;
      _mountedWidgets.add(widget);
      final scope = element.getInheritedWidgetOfExactType<TimeScopeProvider>()?.scope;
      if (widget is MediaCarrier) {
        final carrier = widget as MediaCarrier;
        final source = carrier.mediaSource;
        final snapshot = carrier.snapshotSource;
        if (source != null) _media.add(source);
        if (snapshot != null) _externalSnapshots.add(snapshot);
      }
      if (widget is GenerativeCarrier) {
        final source = (widget as GenerativeCarrier).generativeSource;
        if (source != null) _generated.add(source);
      }
      if (widget is GenerativeMedia && scope != null) {
        _generatedVisuals.add((widget: widget, scope: scope));
      }
      if (widget is ClipPainter && scope != null) {
        _addClip((
          source: widget.source,
          windowStart: scope.startFrame,
          windowLength: scope.durationFrames,
          trim: widget.trim,
          speed: widget.speed,
          sourceTimeMap: widget.speedRamp == null
              ? null
              : integrateClipSpeedRamp(
                  widget.speedRamp!,
                  fps: scope.fps,
                  windowFrames: scope.durationFrames,
                ),
        ));
      }
      if (widget is fluvie.Clip && scope != null && !widget.audio.muted) {
        final transitionAudio = element.getInheritedWidgetOfExactType<ClipTransitionAudioScope>();
        final plan = (
          source: widget.source,
          startFrame: scope.startFrame,
          windowFrames: scope.durationFrames,
          audio: transitionAudio?.audioFor(widget.audio) ?? widget.audio,
          trim: widget.trim,
          speed: widget.speed,
          sourceTimeMap: widget.speedRamp == null
              ? null
              : integrateClipSpeedRamp(
                  widget.speedRamp!,
                  fps: scope.fps,
                  windowFrames: scope.durationFrames,
                ),
        );
        _clipAudio[_audioKey(plan)] = plan;
      }
      if (widget is Image) _images.add((provider: widget.image, context: element));
      if (widget is Snapshot) _snapshots.add(widget);
      if (widget is SnapshotPreparationBoundary &&
          element is StatefulElement &&
          element.state is SnapshotPreparationBoundaryState) {
        final state = element.state as SnapshotPreparationBoundaryState;
        _snapshotBoundaries.add((
          snapshot: widget.snapshot as Snapshot,
          targetKey: state.boundaryKey,
          captureKey: state.captureKey,
          frame: scope?.startFrame ?? 0,
        ));
      }
      if (widget is CaptionsLayer) _captions.add(widget.captions.captionSource);
      if (widget is MotionTarget &&
          widget.animations.any(
            (animation) => animation.effect is ReactiveEffect || animation.at is BeatTrigger,
          )) {
        _needsAudioAnalysis = true;
      }
      if (widget is EffectStack &&
          stackLayersAtStart(widget).any((pair) => pair.$2 is ReactiveEffect)) {
        _needsAudioAnalysis = true;
      }
      if (widget is Video && scope == null) {
        _addExplicit(
          widget.resources,
          TimeScopeData(fps: widget.fps, startFrame: 0, durationFrames: widget.totalFrames),
        );
      } else if (widget is Scene && scope != null) {
        _addExplicit(widget.resources, scope);
      } else if (widget is CompositionResourceScope && scope != null) {
        _addExplicit(widget.resources, scope);
      }
      element.visitChildren(visit);
    }

    (root as Element).visitChildren(visit);
    _implicitShaders.addAll(
      collectShaderAssets([Scene(duration: const Time.frames(1), children: _mountedWidgets)]),
    );
    final v = video;
    if (v != null) {
      _addExplicit(
        v.resources,
        TimeScopeData(fps: v.fps, startFrame: 0, durationFrames: v.totalFrames),
      );
    }
    return before != _fingerprint;
  }

  String get _fingerprint =>
      '${_media.length}:${_generated.length}:${_externalSnapshots.length}:'
      '${_clips.keys.join('|')}:${_clipAudio.keys.join('|')}:${_explicitShaders.join('|')}:${_implicitShaders.join('|')}:${_images.map((image) => image.provider.hashCode).join('|')}:${_snapshots.length}:${_captions.length}:${_additionalAudio.length}:$_needsAudioAnalysis';
  String _clipKey(ClipPlan p) =>
      '${p.source.hashCode}:${p.windowStart}:${p.windowLength}:${p.trim}:${p.speed}:${p.sourceTimeMap}';
  String _audioKey(ClipAudioPlan p) =>
      '${p.source.hashCode}:${p.startFrame}:${p.windowFrames}:${p.trim}:${p.speed}:${p.audio.hashCode}:${p.sourceTimeMap}';
  void _addClip(ClipPlan plan) {
    _clips[_clipKey(plan)] = plan;
    _media.add(plan.source);
  }

  void _addExplicit(CompositionResources resources, TimeScopeData owner) {
    _media.addAll(resources.media);
    _explicitMedia.addAll(resources.media);
    _generated.addAll(resources.generative);
    _externalSnapshots.addAll(resources.snapshots);
    _explicitShaders.addAll(resources.shaderAssets);
    _additionalAudio.addAll(resources.audio);
    _captions.addAll(resources.captions);
    _needsAudioAnalysis |= resources.requiresAudioAnalysis || resources.audio.isNotEmpty;
    for (final resource in resources.clips) {
      final scope = elementScopeFor(resource.window, owner);
      _addClip((
        source: resource.source,
        windowStart: scope.startFrame,
        windowLength: scope.durationFrames,
        trim: resource.trim,
        speed: resource.speed,
        sourceTimeMap: null,
      ));
      if (!resource.audio.muted) {
        final plan = (
          source: resource.source,
          startFrame: scope.startFrame,
          windowFrames: scope.durationFrames,
          audio: resource.audio,
          trim: resource.trim,
          speed: resource.speed,
          sourceTimeMap: null,
        );
        _clipAudio[_audioKey(plan)] = plan;
      }
    }
  }
}
