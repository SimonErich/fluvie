part of 'canvas_interaction.dart';

/// The pointer and keyboard handlers of [_CanvasInteractionState]: routing
/// (gizmo first, then elements, then the marquee), the drag session
/// lifecycle, and the arrow-key nudge.
extension _CanvasGestures on _CanvasInteractionState {
  /// Constant on-screen hit targets, mapped into canvas units.
  double get _handleRadius => 8 / widget.viewport.scale;

  double get _rotationRadius => 20 / widget.viewport.scale;

  Rect? get _marqueeViewportRect {
    final start = _marqueeStart;
    final end = _marqueeEnd;
    if (start == null || end == null) return null;
    return Rect.fromPoints(widget.viewport.toViewport(start), widget.viewport.toViewport(end));
  }

  /// An effect chip dropped over the canvas: the element under the pointer
  /// gains it, through exactly the command a browser tap dispatches. Past
  /// every element the drop is a no-op — there is nothing to put it on.
  void _onEffectDrop(DragTargetDetails<EffectDragData> details) {
    // Mid-transition the geometry does not match the picture; the same gate
    // every pointer gesture honors.
    if (!_sceneSettled) return;
    final box = context.findRenderObject();
    if (box is! RenderBox) return;
    final canvasPoint = widget.viewport.toCanvas(box.globalToLocal(details.offset));
    final hit = _geometry.hitTest(canvasPoint, skip: _untouchable);
    if (hit == null) return;
    widget.onCommand?.call(AddEffectCommand(id: hit, effect: details.data.effect));
    ref.read(selectionProvider.notifier).click(hit);
  }

  void _onTapUp(TapUpDetails details) {
    if (!_sceneSettled) return;
    final canvasPoint = widget.viewport.toCanvas(details.localPosition);
    final tool = _toolState;
    if (tool.places) {
      _placeAt(tool, canvasPoint);
      return;
    }
    final hit = _geometry.hitTest(canvasPoint, skip: _untouchable);
    if (hit == null && _entered == null && _handleSlotTap(canvasPoint)) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (hit != null && hit == _lastTapId && now - _lastTapMs < 350) {
      final element = widget.document.elementJson(hit);
      if (const {'Text', 'SplitText'}.contains(element?['type'])) {
        _rebuild(() => _textEdit = (id: hit, initial: element!['text']! as String));
        return;
      }
      if (element?['type'] == 'Group' && _entered == null) {
        ref.read(enteredGroupProvider.notifier).enter(hit);
        ref.read(selectionProvider.notifier).clear();
        return;
      }
    }
    _lastTapId = hit;
    _lastTapMs = now;
    if (hit == null && _entered != null) {
      _tapOutsideEnteredGroup(canvasPoint);
      return;
    }
    ref.read(selectionProvider.notifier).click(hit, additive: _shift);
  }

  void _onHover(PointerHoverEvent event) {
    if (!_sceneSettled) return;
    final canvasPoint = widget.viewport.toCanvas(event.localPosition);
    final gizmo = _gizmo;
    final gizmoHit = gizmo?.hitTest(
      canvasPoint,
      handleRadius: _handleRadius,
      rotationRadius: _rotationRadius,
    );
    final hovered = _geometry.hitTest(canvasPoint, skip: _untouchable);
    final cursor = gizmoHit == null ? MouseCursor.defer : gizmo!.cursorFor(gizmoHit);
    if (hovered != _hovered || cursor != _cursor) {
      _rebuild(() {
        _hovered = hovered;
        _cursor = cursor;
      });
    }
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (_session != null) {
        _clearSession();
      } else if (_toolState.tool != EditorTool.select) {
        ref.read(toolProvider.notifier).reset();
      } else if (_entered case final String entered) {
        ref.read(enteredGroupProvider.notifier).exit();
        ref.read(selectionProvider.notifier).select({entered});
      } else {
        ref.read(selectionProvider.notifier).clear();
      }
      return KeyEventResult.handled;
    }
    if (_session == null && _textEdit == null) {
      // The registry first: the same bindings the menus and the palette
      // advertise (clipboard, arrange, lock and hide, delete).
      final registry = _registryShortcut(key);
      if (registry != null) return registry;
    }
    final toolState = ToolController.toolForKey(key);
    if (toolState != null && _session == null && _textEdit == null && !_shift && !_alt) {
      ref.read(toolProvider.notifier).apply(toolState);
      return KeyEventResult.handled;
    }
    final direction = switch (key) {
      LogicalKeyboardKey.arrowLeft => const Offset(-1, 0),
      LogicalKeyboardKey.arrowRight => const Offset(1, 0),
      LogicalKeyboardKey.arrowUp => const Offset(0, -1),
      LogicalKeyboardKey.arrowDown => const Offset(0, 1),
      _ => null,
    };
    if (direction == null) return KeyEventResult.ignored;
    return _nudge(direction);
  }
}
