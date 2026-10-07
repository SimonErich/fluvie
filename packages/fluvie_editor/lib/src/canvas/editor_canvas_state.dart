part of 'editor_canvas.dart';

final class _EditorCanvasState extends State<EditorCanvas> {
  final SlideDeriver _deriver = SlideDeriver();
  final ValueNotifier<Map<String, Placement>> _overrides = ValueNotifier(const {});
  late final CanvasViewportController _ownViewport;
  LivePlaybackController? _clock;
  Size? _fittedFor;
  late Video _wholeVideo;
  String? _wholeDigest;
  String? _mediaError;

  CanvasViewportController get _viewport => widget.viewportController ?? _ownViewport;

  @override
  void initState() {
    super.initState();
    _ownViewport = CanvasViewportController();
  }

  @override
  void dispose() {
    _clock?.dispose();
    _overrides.dispose();
    _ownViewport.dispose();
    super.dispose();
  }

  late EditorDocument _draftDocument;
  String? _draftDigest;
  Object? _clockFor;

  EditorDocument get _previewDocument {
    if (!widget.bypassEffects) return widget.document;
    final digest = widget.document.renderDigest;
    if (_draftDigest != digest) {
      final json = widget.document.toJson();
      void strip(Object? value) {
        if (value is Map<String, Object?>) {
          value.remove('effects');
          value.values.forEach(strip);
        } else if (value is List) {
          value.forEach(strip);
        }
      }

      strip(json);
      _draftDocument = EditorDocument.fromJson(json);
      _draftDigest = digest;
    }
    return _draftDocument;
  }

  Size get _canvasSize {
    final size = widget.document.spec.size;
    return Size(size.width.toDouble(), size.height.toDouble());
  }

  /// The clock the stage mounts: the shared transport's, or — without a
  /// transport — a fresh canvas-owned clock held at the slide's settled
  /// frame (the previous one retires with the previous slide subtree).
  LivePlaybackController _stageClock(DerivedSlide derived) {
    final transport = widget.transport;
    if (transport != null) return transport.controller;
    if (identical(_clockFor, derived) && _clock != null) return _clock!;
    _clockFor = derived;
    _clock?.dispose();
    return _clock = LivePlaybackController(fps: widget.document.spec.fps)
      ..hold(derived.settleFrame);
  }

  /// What the stage mounts: the single derived slide, or — in
  /// [EditorCanvas.wholeDocument] mode — the full composition built once
  /// per render digest, on the transport's absolute clock.
  ({Widget content, LivePlaybackController clock, Key key}) _stage() {
    final document = _previewDocument;
    if (widget.wholeDocument) {
      final digest = document.renderDigest;
      if (digest != _wholeDigest) {
        _wholeDigest = digest;
        _wholeVideo = document.spec.build();
      }
      return (
        content: _wholeVideo,
        clock: widget.transport!.controller,
        key: ValueKey('video:$digest'),
      );
    }
    final derived = _deriver.derive(document, widget.slide);
    return (content: derived.video, clock: _stageClock(derived), key: ObjectKey(derived));
  }

  @override
  Widget build(BuildContext context) {
    final mount = _stage();
    final colors = context.colors;
    return ColoredBox(
      color: colors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewportSize = constraints.biggest;
          if (_fittedFor == null) {
            // First layout: nothing listens yet, fit synchronously so the
            // very first frame is already framed.
            _fittedFor = viewportSize;
            _viewport.fit(_canvasSize, viewportSize, margin: widget.fitMargin);
          } else if (_fittedFor != viewportSize) {
            // A resize mid-life: refit after the frame (listeners exist).
            _fittedFor = viewportSize;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _viewport.fit(_canvasSize, viewportSize, margin: widget.fitMargin);
            });
          }
          final stage = _EditorCanvasStage(
            viewport: _viewport,
            canvasSize: _canvasSize,
            canvas: widget,
            mount: mount,
            shadowColor: colors.overlay.withValues(alpha: 0.35),
            overrides: _overrides,
            onError: (error) {
              if (mounted) setState(() => _mediaError = error.toString());
            },
            onReady: (resolver) {
              if (mounted && _mediaError != null) setState(() => _mediaError = null);
              widget.onMediaReady?.call(resolver);
            },
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              stage,
              if (_mediaError != null)
                Positioned(
                  left: 8,
                  right: 8,
                  top: 8,
                  child: Semantics(
                    liveRegion: true,
                    child: ColoredBox(
                      color: colors.surface,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          'Media preview unavailable: $_mediaError',
                          maxLines: 3,
                          style: TextStyle(color: colors.text),
                        ),
                      ),
                    ),
                  ),
                ),
              if (widget.interactive)
                CanvasInteraction(
                  document: widget.document,
                  slide: widget.slide,
                  viewport: _viewport,
                  overrides: _overrides,
                  // Only the whole-document preview parks a scene mid-transition;
                  // the derived-slide stage always holds a settled still.
                  transport: widget.wholeDocument ? widget.transport : null,
                  settleFrame: widget.settleFrame,
                  onCommand: widget.onCommand,
                  onShowSlide: widget.onShowSlide,
                ),
            ],
          );
        },
      ),
    );
  }
}
