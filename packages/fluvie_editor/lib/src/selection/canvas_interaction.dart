import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/selection/scene_geometry.dart';
import 'package:fluvie_editor/src/selection/selection_chrome.dart';
import 'package:fluvie_editor/src/selection/selection_controller.dart';
import 'package:fluvie_editor/src/widgets/canvas_viewport.dart';

/// The canvas's input layer: clicks select, shift-clicks extend, a drag on
/// empty canvas sweeps a marquee, Space plus drag pans, hover outlines —
/// every position resolved against the document's geometry through the one
/// shared camera mapping.
final class CanvasInteraction extends ConsumerStatefulWidget {
  /// Wires input over slide [slide] of [document] under [viewport]'s camera.
  const CanvasInteraction({
    required this.document,
    required this.slide,
    required this.viewport,
    super.key,
  });

  /// The deck being edited.
  final EditorDocument document;

  /// The scene index on stage.
  final int slide;

  /// The camera; positions map through it.
  final CanvasViewportController viewport;

  @override
  ConsumerState<CanvasInteraction> createState() => _CanvasInteractionState();
}

final class _CanvasInteractionState extends ConsumerState<CanvasInteraction> {
  Offset? _marqueeStart;
  Offset? _marqueeEnd;
  String? _hovered;

  SceneGeometry get _geometry => SceneGeometry.of(widget.document, widget.slide);

  // Not const: LogicalKeyboardKey has no primitive equality.
  static final Set<LogicalKeyboardKey> _shiftKeys = {
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
  };

  bool get _additive => HardwareKeyboard.instance.logicalKeysPressed.any(_shiftKeys.contains);

  bool get _panning =>
      HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.space);

  Rect? get _marqueeViewportRect {
    final start = _marqueeStart;
    final end = _marqueeEnd;
    if (start == null || end == null) return null;
    return Rect.fromPoints(widget.viewport.toViewport(start), widget.viewport.toViewport(end));
  }

  void _onTapUp(TapUpDetails details) {
    final hit = _geometry.hitTest(widget.viewport.toCanvas(details.localPosition));
    ref.read(selectionProvider.notifier).click(hit, additive: _additive);
  }

  void _onHover(PointerHoverEvent event) {
    final hit = _geometry.hitTest(widget.viewport.toCanvas(event.localPosition));
    if (hit != _hovered) setState(() => _hovered = hit);
  }

  void _onPanStart(DragStartDetails details) {
    if (_panning) return;
    final canvasPoint = widget.viewport.toCanvas(details.localPosition);
    if (_geometry.hitTest(canvasPoint) != null) return;
    setState(() {
      _marqueeStart = canvasPoint;
      _marqueeEnd = canvasPoint;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_panning) {
      widget.viewport.panBy(details.delta);
      return;
    }
    if (_marqueeStart == null) return;
    setState(() => _marqueeEnd = widget.viewport.toCanvas(details.localPosition));
  }

  void _onPanEnd(DragEndDetails details) {
    final start = _marqueeStart;
    final end = _marqueeEnd;
    if (start == null || end == null) return;
    final swept = Rect.fromPoints(start, end);
    ref
        .read(selectionProvider.notifier)
        .marquee(_geometry.hitTestMarquee(swept), additive: _additive);
    setState(() {
      _marqueeStart = null;
      _marqueeEnd = null;
    });
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
      ref.read(selectionProvider.notifier).clear();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectionProvider);
    final marquee = _marqueeViewportRect;
    return Focus(
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: MouseRegion(
        onHover: _onHover,
        onExit: (_) => setState(() => _hovered = null),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          // The marquee anchors where the pointer went down, not where the
          // recognizer won the arena.
          dragStartBehavior: DragStartBehavior.down,
          onTapUp: _onTapUp,
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: Stack(
            fit: StackFit.expand,
            children: [
              SelectionChrome(
                geometry: _geometry,
                viewport: widget.viewport,
                selected: selected,
                hovered: _hovered,
              ),
              if (marquee != null) MarqueeOverlay(rect: marquee),
            ],
          ),
        ),
      ),
    );
  }
}
