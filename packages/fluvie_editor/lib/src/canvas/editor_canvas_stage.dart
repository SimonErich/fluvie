part of 'editor_canvas.dart';

final class _EditorCanvasStage extends StatelessWidget {
  const _EditorCanvasStage({
    required this.viewport,
    required this.canvasSize,
    required this.canvas,
    required this.mount,
    required this.shadowColor,
    required this.overrides,
    required this.onError,
    required this.onReady,
  });

  final CanvasViewportController viewport;
  final Size canvasSize;
  final EditorCanvas canvas;
  final ({Widget content, LivePlaybackController clock, Key key}) mount;
  final Color shadowColor;
  final ValueNotifier<Map<String, Placement>> overrides;
  final ValueChanged<Object> onError;
  final ValueChanged<MediaResolver> onReady;

  Widget _scopePreview(
    ({Widget content, LivePlaybackController clock, Key key}) mount,
    Widget child,
  ) {
    final scopes = canvas.scopes;
    return scopes == null
        ? child
        : ScopePreview(
            controller: scopes,
            clock: mount.clock,
            digest:
                '${canvas.document.renderDigest}:${canvas.bypassEffects}:${canvas.wholeDocument ? 'video' : canvas.slide}',
            child: child,
          );
  }

  @override
  Widget build(BuildContext context) => CanvasViewport(
    controller: viewport,
    canvasSize: canvasSize,
    child: DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [BoxShadow(color: shadowColor, blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: KeyedSubtree(
        key: mount.key,
        child: PreviewMediaScope(
          composition: mount.content,
          warmEffects: false,
          frames: mount.clock.frames,
          resolver: canvas.mediaResolver,
          clipDecoder: canvas.clipDecoder,
          maxClipEdge: canvas.previewMaxEdge,
          onError: onError,
          onReady: onReady,
          child: EffectWarmHost(
            composition: mount.content,
            child: _scopePreview(
              mount,
              LivePlayer(
                controller: mount.clock,
                // The transform-only fast path: a drag streams placements
                // into [_overrides]; only the dragged elements re-place,
                // the derived subtree itself never rebuilds.
                child: ValueListenableBuilder<Map<String, Placement>>(
                  valueListenable: overrides,
                  child: mount.content,
                  builder: (context, overrides, child) =>
                      PlacedOverrides(overrides: overrides, child: child!),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
