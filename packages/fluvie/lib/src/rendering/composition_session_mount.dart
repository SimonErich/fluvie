part of 'composition_session.dart';

extension _SessionMount on CompositionSession {
  PreparedComposition _prepared() {
    if (!_resourcesPrepared) throw StateError('Prepare the composition before reading its plan.');
    return PreparedComposition(
      video: video,
      clipPlans: clipPlans,
      clipAudioPlans: clipAudioPlans,
      mediaSources: mediaSources,
      snapshots: snapshots,
      fps: fps,
      totalFrames: video?.totalFrames ?? hostFrameCount,
    );
  }

  Widget _mountTree(Widget child) {
    Widget tree = KeyedSubtree(key: mountKey, child: child);
    if (!preparing || _resolvingTiming || selectedSnapshotBoundary != null) {
      tree = beatGridScopeFor(reactiveTracks, resolver, tree);
      tree = reactiveScopeFor(reactiveTracks, resolver, tree);
    }
    if (!preparing || selectedSnapshotBoundary != null) {
      tree = ImageResolverScope(resolver: resolver, child: tree);
      if (_generated.isNotEmpty) tree = GenerativeResolverScope(resolver: generative, child: tree);
      if (shaderPrograms.isNotEmpty) tree = WarmShaderScope(programs: shaderPrograms, child: tree);
      if (colorLookups.isNotEmpty) tree = ColorLookupScope(lookups: colorLookups, child: tree);
    }
    return PreparationScope(
      preparing: preparing,
      resolver: resolver,
      onAudioAnalysis: () => _needsAudioAnalysis = true,
      resolvingTiming: _resolvingTiming,
      onTimingError: (error) => _timingError = preparing
          ? error
          : FluvieTimingError('At frame $_frame: ${error.message}', anchors: error.anchors),
      requireResource: _requirePrepared,
      snapshotTarget: selectedSnapshotBoundary,
      child: tree,
    );
  }

  void _dispose() {
    for (final image in colorLookups.values) {
      image.dispose();
    }
    colorLookups = {};
  }
}
