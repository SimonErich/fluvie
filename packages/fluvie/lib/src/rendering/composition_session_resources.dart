part of 'composition_session.dart';

extension _SessionPreparation on CompositionSession {
  Future<void> _prepareFrame(int frame) async {
    _frame = frame;
    await _frames?.prepare(frame);
    final preparer = resolver;
    if (preparer is ClipFramePreparer) {
      for (final plan in _clips.values) {
        final meta = resolver.clipMetadataFor(plan.source);
        final timeline = clipTimelineFor(resolver, plan.source);
        final bounds = resolveClipTrimBounds(plan.trim, meta, timeline: timeline);
        final offsets = resolveClipTrimOffsets(plan.trim, meta, timeline: timeline);
        (preparer as ClipFramePreparer).registerClipPlan(
          source: plan.source,
          windowStart: plan.windowStart,
          windowLength: plan.windowLength,
          compFps: fps,
          trimStartFrames: bounds.start,
          trimEndFrames: bounds.end,
          trimStartOffsetFrames: offsets.start - bounds.start,
          trimEndOffsetFrames: offsets.end - bounds.end,
          speed: plan.speed,
          sourceTimeMap: plan.sourceTimeMap,
        );
      }
      await (preparer as ClipFramePreparer).prepareClipFrames(frame);
    }
  }

  /// Prepares the current manifest; every synchronous paint lookup is warmed.
  Future<void> _prepareResources({
    bool decodeImages = true,
    bool warmEffects = true,
    bool prepareSnapshots = true,
  }) async {
    final pending = _generated.difference(_preparedGenerated);
    if (pending.isNotEmpty) {
      await generative.generateAll(pending, onProgress: onGenerativeProgress);
      _preparedGenerated.addAll(pending);
    }
    for (final source in _generated) {
      if (source.kind == GenerativeKind.image || source.kind == GenerativeKind.video) {
        _media.add(generative.mediaFor(source));
      }
    }
    // Explicitly typed Clip painters win over filename guesses, including
    // unlabeled memory clips. Their probe loads their bytes itself.
    for (final visual in _generatedVisuals) {
      if (visual.widget.source.kind != GenerativeKind.video) continue;
      final source = generative.mediaFor(visual.widget.source);
      final scope = visual.scope;
      _addClip((
        source: source,
        windowStart: scope.startFrame,
        windowLength: scope.durationFrames,
        trim: visual.widget.trim,
        speed: 1,
        sourceTimeMap: null,
      ));
      if (!visual.widget.audio.muted && generative.metaFor(visual.widget.source).hasAudio) {
        final plan = (
          source: source,
          startFrame: scope.startFrame,
          windowFrames: scope.durationFrames,
          audio: visual.widget.audio,
          trim: visual.widget.trim,
          speed: 1.0,
          sourceTimeMap: null,
        );
        _clipAudio[_audioKey(plan)] = plan;
      }
    }
    final clipSources = _clips.values.map((plan) => plan.source).toSet();
    await resolver.preResolveAll(
      _media.where((source) => !clipSources.contains(source) || isClipSource(source)),
    );
    for (final source in clipSources) {
      await resolver.probeClip(source);
    }
    if (prepareSnapshots && _externalSnapshots.isNotEmpty) {
      final service = snapshotService;
      if (service == null) {
        throw FluvieRenderException(
          'This composition needs a SnapshotService '
          'for Mermaid, Html or WebView. Supply snapshotService before rendering.',
        );
      }
      await resolver.preResolveSnapshots(_externalSnapshots, service);
    }
    final v = video;
    if (v?.captions case final caption?) _captions.add(caption.captionSource);
    for (final source in _captions) {
      await resolver.preResolveCaptions(source);
    }
    if (v != null) {
      if (_needsAudioAnalysis && !_audioPrepared) {
        final declared = collectReactiveTracks(v);
        final tracks = ReactiveTracks(
          byAnchor: declared.byAnchor,
          windows: declared.windows,
          windowsByAnchor: declared.windowsByAnchor,
          defaultSource: declared.defaultSource ?? _additionalAudio.firstOrNull,
          allSources: {...declared.allSources, ..._additionalAudio},
        );
        if (tracks.allSources.isNotEmpty) {
          final defaults = beatDetector == null || analyzer == null
              ? defaultPreparationAudio(whenCancelled: cancellation?.whenCancelled)
              : null;
          try {
            final windowsResolver = resolver;
            if (windowsResolver is AudioWindowResolver && tracks.windows.isNotEmpty) {
              await (windowsResolver as AudioWindowResolver).preResolveAudioWindows(
                tracks.windows,
                beatDetector: beatDetector ?? defaults!.beats,
                analyzer: analyzer ?? defaults!.bands,
              );
            } else {
              await resolver.preResolveReactive(
                tracks.allSources,
                beatDetector: beatDetector ?? defaults!.beats,
                analyzer: analyzer ?? defaults!.bands,
                fps: v.fps,
                totalFrames: v.totalFrames,
              );
            }
          } finally {
            defaults?.dispose();
          }
          reactiveTracks = tracks;
        }
        _audioPrepared = true;
      }
    }
    if (warmEffects) {
      final declared = Video(
        scenes: [Scene(duration: const Time.frames(1), children: _mountedWidgets)],
      );
      shaderPrograms.addAll(
        await preLoadShaders(
          {
            ...collectShaderAssets(declared.scenes),
            ..._explicitShaders,
          }.where((name) => !shaderPrograms.containsKey(name)),
        ),
      );
      // New geometries may expose new LUTs, so bake the discovered plan again
      // and retain already owned images rather than replacing live handles.
      final baked = await preBakeCompositionColorLookups(
        composition: declared,
        loadCubeText: loadCubeText,
      );
      for (final entry in baked.entries) {
        if (colorLookups.containsKey(entry.key)) {
          entry.value.dispose();
        } else {
          colorLookups[entry.key] = entry.value;
        }
      }
    }
    _frames = PreviewClipFrames.fromPlans(
      resolver,
      clipPlans,
      fps: fps,
      lookaheadFrames: clipLookaheadFrames,
    );
    if (decodeImages) {
      final images = [..._images];
      final context = mountKey.currentContext;
      if (context != null) {
        for (final source in _explicitMedia) {
          // Inference widens these different ImageProvider types to Object.
          // ignore: omit_local_variable_types
          final ImageProvider<Object>? provider = switch (source) {
            AssetSource(:final name) => AssetImage(name),
            NetworkSource(:final url) => NetworkImage('$url'),
            MemorySource(:final bytes) => MemoryImage(bytes),
            FileSource() => null,
          };
          if (provider != null) images.add((provider: provider, context: context));
        }
      }
      for (final image in images) {
        if (!_warmedImages.add(image.provider)) continue;
        Object? error;
        await precacheImage(
          image.provider,
          image.context,
          onError: (failure, _) => error = failure,
        );
        if (error != null) {
          throw FluvieRenderException('Flutter Image could not be prepared: $error');
        }
      }
    }
  }
}
