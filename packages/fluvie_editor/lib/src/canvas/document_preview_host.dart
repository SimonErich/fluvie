import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart' show LivePlaybackController, LivePlayer, PreviewMediaScope;
import 'package:fluvie/rendering.dart' show MediaResolver, WebClipDecoder;
import 'package:fluvie_editor/src/canvas/effect_warm_host.dart';
import 'package:fluvie_editor/src/canvas/slide_deriver.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';

/// The editor's hidden preview stage: renders one document slide at a time
/// at thumbnail size, settled, and captures it — the `renderSlide` the
/// presenter's `SlidePreviewService` cache is bound to.
///
/// The service (lazy, capped, deduplicating) stays presenter-owned; this
/// host only adapts it to a document instead of a compiled presentation.
final class DocumentPreviewHost extends StatefulWidget {
  /// Creates the host over [document].
  const DocumentPreviewHost({
    required this.document,
    this.thumbWidth = 320,
    this.mediaResolver,
    this.clipDecoder,
    super.key,
  });

  /// The deck being edited.
  final EditorDocument document;

  /// The rendered preview width; height follows the canvas aspect.
  final double thumbWidth;

  /// Optional caller-owned media resolver, shared with test or host infrastructure.
  final MediaResolver? mediaResolver;

  /// Browser decoder for real clip thumbnails and still exports.
  final WebClipDecoder? clipDecoder;

  @override
  State<DocumentPreviewHost> createState() => DocumentPreviewHostState();
}

/// The host's rendering surface — public so the panel can bind the preview
/// service's renderer to [render].
final class DocumentPreviewHostState extends State<DocumentPreviewHost> {
  final SlideDeriver _deriver = SlideDeriver();
  final GlobalKey _boundary = GlobalKey();
  final _warmHost = GlobalKey<EffectWarmHostState>();
  Future<void> _serial = Future.value();
  LivePlaybackController? _clock;
  int? _request;
  late DerivedSlide _derived;
  EditorDocument? _renderDocument;
  Completer<Object?>? _mediaReady;

  double get _thumbHeight {
    final size = (_renderDocument ?? widget.document).spec.size;
    return widget.thumbWidth * size.height / size.width;
  }

  /// Renders slide [slide]'s settled state to an image. Calls serialize:
  /// the host shows one composition at a time.
  ///
  /// A deck can close while previews are still rendering, so a host that is
  /// gone (before the render starts, while it waits its turn, or while the
  /// boundary is being read back) fails the returned future with a
  /// [StateError] instead of capturing a stage that is no longer there.
  Future<ui.Image> render(int slide) {
    if (!mounted) return Future<ui.Image>.error(_hostGone(slide), StackTrace.current);
    final result = _serial.then((_) => _renderNow(slide));
    // The chain only sequences renders; the failure itself stays on the
    // future the caller holds.
    _serial = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<ui.Image> _renderNow(int slide) async {
    if (!mounted) throw _hostGone(slide);
    _renderDocument = widget.document;
    _derived = _deriver.derive(_renderDocument!, slide);
    _clock?.dispose();
    _clock = LivePlaybackController(fps: _renderDocument!.spec.fps)..hold(_derived.settleFrame);
    final mediaReady = _mediaReady = Completer<Object?>();
    setState(() => _request = slide);
    try {
      // Three frames: mount and collect, resolve post-frame, paint settled.
      for (var i = 0; i < 3; i++) {
        await WidgetsBinding.instance.endOfFrame;
      }
      if (!mounted) throw _hostGone(slide);
      final mediaWasPending = !mediaReady.isCompleted;
      final mediaError = await mediaReady.future;
      if (mediaError != null) {
        Error.throwWithStackTrace(mediaError, StackTrace.current);
      }
      if (!mounted) throw _hostGone(slide);
      if (mediaWasPending) {
        for (var i = 0; i < 2; i++) {
          await WidgetsBinding.instance.endOfFrame;
        }
      }
      final warm = _warmHost.currentState;
      if (warm != null && !warm.isReady) {
        await warm.ready;
        // Only a late resource load needs extra frames after the usual settle.
        for (var i = 0; i < 2; i++) {
          await WidgetsBinding.instance.endOfFrame;
        }
      }
      final boundary = _boundary.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) throw _hostGone(slide);
      final image = await boundary.toImage();
      return image;
    } finally {
      if (mounted) setState(() => _request = null);
    }
  }

  StateError _hostGone(int slide) =>
      StateError('The preview host closed before slide $slide rendered.');

  @override
  void dispose() {
    final pending = _mediaReady;
    if (pending != null && !pending.isCompleted) pending.complete(_hostGone(_request ?? 0));
    _clock?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final request = _request;
    if (request == null) return const SizedBox.shrink();
    final derived = _derived;
    final clock = _clock!;
    final document = _renderDocument!;
    final ready = _mediaReady!;
    return SizedBox(
      width: widget.thumbWidth,
      height: _thumbHeight,
      child: RepaintBoundary(
        key: _boundary,
        child: FittedBox(
          child: SizedBox(
            width: document.spec.size.width.toDouble(),
            height: document.spec.size.height.toDouble(),
            child: PreviewMediaScope(
              composition: derived.video,
              frames: clock.frames,
              resolver: widget.mediaResolver,
              clipDecoder: widget.clipDecoder,
              maxClipEdge: null,
              warmEffects: false,
              onReady: (_) {
                if (!ready.isCompleted) ready.complete();
              },
              onError: (error) {
                if (!ready.isCompleted) ready.complete(error);
              },
              child: EffectWarmHost(
                key: _warmHost,
                composition: derived.video,
                child: LivePlayer(controller: clock, child: derived.video),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
