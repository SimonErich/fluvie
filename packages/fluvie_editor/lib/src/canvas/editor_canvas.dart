import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart' show LivePlaybackController, LivePlayer;
import 'package:fluvie_editor/src/canvas/slide_deriver.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/selection/canvas_interaction.dart';
import 'package:fluvie_editor/src/widgets/canvas_viewport.dart';
import 'package:obers_ui/obers_ui.dart' show OiBuildContextThemeExt;

/// The editing stage: one slide of the document, rendered by the same
/// fluvie pipeline that presents and exports it, held at its settled frame
/// on a soft backdrop inside a zoomable viewport.
final class EditorCanvas extends StatefulWidget {
  /// Shows [slide] of [document].
  const EditorCanvas({
    required this.document,
    required this.slide,
    this.viewportController,
    this.fitMargin = 48,
    this.interactive = false,
    super.key,
  });

  /// The deck being edited.
  final EditorDocument document;

  /// The scene index on stage.
  final int slide;

  /// The camera; pass one to drive zoom commands from outside. `null` and
  /// the canvas owns a camera itself.
  final CanvasViewportController? viewportController;

  /// Breathing room around the slide when it first fits the viewport.
  final double fitMargin;

  /// Whether the selection input layer mounts over the slide (Phase 2's
  /// editing surface; false keeps the canvas a pure viewer).
  final bool interactive;

  @override
  State<EditorCanvas> createState() => _EditorCanvasState();
}

final class _EditorCanvasState extends State<EditorCanvas> {
  final SlideDeriver _deriver = SlideDeriver();
  late final CanvasViewportController _ownViewport;
  LivePlaybackController? _clock;
  Size? _fittedFor;

  CanvasViewportController get _viewport => widget.viewportController ?? _ownViewport;

  @override
  void initState() {
    super.initState();
    _ownViewport = CanvasViewportController();
  }

  @override
  void dispose() {
    _clock?.dispose();
    _ownViewport.dispose();
    super.dispose();
  }

  Size get _canvasSize {
    final size = widget.document.spec.size;
    return Size(size.width.toDouble(), size.height.toDouble());
  }

  /// A fresh clock held at the slide's settled frame; the previous clock
  /// retires with the previous slide subtree.
  LivePlaybackController _heldClock(DerivedSlide derived) {
    _clock?.dispose();
    return _clock = LivePlaybackController(fps: widget.document.spec.fps)
      ..hold(derived.settleFrame);
  }

  @override
  Widget build(BuildContext context) {
    final derived = _deriver.derive(widget.document, widget.slide);
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
          final stage = CanvasViewport(
            controller: _viewport,
            canvasSize: _canvasSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: colors.overlay.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: KeyedSubtree(
                key: ObjectKey(derived),
                child: LivePlayer(controller: _heldClock(derived), child: derived.video),
              ),
            ),
          );
          if (!widget.interactive) return stage;
          return Stack(
            fit: StackFit.expand,
            children: [
              stage,
              CanvasInteraction(
                document: widget.document,
                slide: widget.slide,
                viewport: _viewport,
              ),
            ],
          );
        },
      ),
    );
  }
}
