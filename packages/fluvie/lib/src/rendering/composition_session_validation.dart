part of 'composition_session.dart';

extension _FrozenResources on CompositionSession {
  void _requirePrepared(Object source, String kind) {
    final declared = switch (source) {
      MediaSource() =>
        kind == 'clip'
            ? _clips.values.any((plan) => plan.source == source)
            : _media.contains(source),
      GenerativeSource() => _generated.contains(source),
      SnapshotSource() => _externalSnapshots.contains(source),
      CaptionSource() => _captions.contains(source),
      String() => _explicitShaders.contains(source) || _implicitShaders.contains(source),
      _ => false,
    };
    if (declared) return;
    throw FluvieRenderException(
      'A $kind resource appeared at frame $_frame after preparation: $source. '
      'Declare every frame-dependent alternative with FrameBuilder(resources: '
      'CompositionResources(...)), CompositionResourceScope, Video.resources or '
      'Scene.resources so it is ready before frame zero.',
    );
  }

  void _validateFrameResources() {
    if (_timingError case final error?) throw error;
    final root = mountKey.currentContext;
    if (root == null) return;
    void visit(Element element) {
      final widget = element.widget;
      if (widget is Image && !_warmedImages.contains(widget.image)) {
        final provider = widget.image;
        final source = switch (provider) {
          AssetImage(:final assetName, :final package) => MediaSource.asset(
            package == null ? assetName : 'packages/$package/$assetName',
          ),
          ExactAssetImage(:final assetName, :final package) => MediaSource.asset(
            package == null ? assetName : 'packages/$package/$assetName',
          ),
          NetworkImage(:final url) => MediaSource.network(Uri.parse(url)),
          MemoryImage(:final bytes) => MediaSource.memory(bytes),
          _ => null,
        };
        if (source == null || !_media.contains(source)) {
          throw FluvieRenderException(
            'Flutter Image resource appeared at frame $_frame after preparation: $provider. '
            'Declare its MediaSource in FrameBuilder.resources or Video.resources; '
            'custom ImageProviders must be visible during preparation.',
          );
        }
      }
      element.visitChildren(visit);
    }

    (root as Element).visitChildren(visit);
  }
}
