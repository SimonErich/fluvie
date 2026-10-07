part of 'canvas_interaction.dart';

/// The canvas drag state machine: pan routing, session updates and release.
/// Live overrides and commits stay in their original evaluation order.
extension _CanvasDragGestures on _CanvasInteractionState {
  void _onPanStart(DragStartDetails details) {
    if (!_sceneSettled) return;
    if (_panning || _toolState.tool == EditorTool.hand) return;
    final canvasPoint = widget.viewport.toCanvas(details.localPosition);
    if (_toolState.places) {
      _rebuild(() {
        _marqueeStart = canvasPoint;
        _marqueeEnd = canvasPoint;
      });
      return;
    }
    final selected = ref.read(selectionProvider);
    final gizmoHit = _gizmo?.hitTest(
      canvasPoint,
      handleRadius: _handleRadius,
      rotationRadius: _rotationRadius,
    );
    if (gizmoHit != null) {
      _beginSession(gizmoHit, selected, canvasPoint, details.localPosition);
      return;
    }
    final elementHit = _geometry.hitTest(canvasPoint, skip: _untouchable);
    if (elementHit != null) {
      // Dragging an unselected element selects it first (shift adds it).
      final ids = selected.contains(elementHit)
          ? selected
          : (_shift ? {...selected, elementHit} : {elementHit});
      if (!setEquals(ids, selected)) ref.read(selectionProvider.notifier).select(ids);
      _beginSession(const GizmoBody(), ids, canvasPoint, details.localPosition);
      return;
    }
    _rebuild(() {
      _marqueeStart = canvasPoint;
      _marqueeEnd = canvasPoint;
    });
  }

  void _beginSession(GizmoHit hit, Set<String> ids, Offset origin, Offset pointerViewport) {
    final targets = _targets(ids);
    if (targets.isEmpty) return;
    _rebuild(() {
      // Inside an entered group the session runs in the group's own frame:
      // local rects, local pointer, the group box as the canvas — so the
      // placements it streams are the group-relative fractions the children
      // actually store.
      _session = GizmoSession.begin(
        hit: hit,
        targets: targets,
        primary: targets.keys.first,
        canvas: _frameSize,
        origin: origin - _frameOrigin,
        snapper: _snapperFor(ids),
      );
      _snapLines = const [];
      _pointerViewport = pointerViewport;
      _cursor = switch (hit) {
        GizmoBody() => SystemMouseCursors.move,
        GizmoRotate() => SystemMouseCursors.grabbing,
        GizmoResize() => _cursor,
      };
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_panning || _toolState.tool == EditorTool.hand) {
      widget.viewport.panBy(details.delta);
      return;
    }
    final tool = _toolState;
    if (tool.places && _marqueeStart != null) {
      var end = widget.viewport.toCanvas(details.localPosition);
      if (_shift && tool.tool == EditorTool.shape) {
        end = constrainedEnd(tool.shape, _marqueeStart!, end);
      }
      _rebuild(() => _marqueeEnd = end);
      return;
    }
    final session = _session;
    if (session != null) {
      widget.overrides.value = session.update(
        widget.viewport.toCanvas(details.localPosition) - _frameOrigin,
        aspect: _shift,
        fromCenter: _alt,
        snap: _shift,
        bypassSnap: _snapBypass,
      );
      _rebuild(() {
        _pointerViewport = details.localPosition;
        _snapLines = session.snapLines;
      });
      return;
    }
    if (_marqueeStart == null) return;
    _rebuild(() => _marqueeEnd = widget.viewport.toCanvas(details.localPosition));
  }

  void _onPanEnd(DragEndDetails details) {
    final session = _session;
    if (session != null) {
      // A block child dropped beyond the group's bounds releases instead of
      // committing (and snapping back into) its slot.
      final release = widget.onCommand == null ? null : _blockReleaseCommand(session);
      final command = release ?? session.commit();
      _clearSession();
      if (command != null) widget.onCommand?.call(command);
      if (release != null) {
        ref.read(enteredGroupProvider.notifier).exit();
        ref.read(selectionProvider.notifier).select({release.childId});
      }
      return;
    }
    final start = _marqueeStart;
    final end = _marqueeEnd;
    if (start == null || end == null) return;
    final tool = _toolState;
    _rebuild(() {
      _marqueeStart = null;
      _marqueeEnd = null;
    });
    if (tool.places) {
      _placeFromDrag(tool, start, end);
      return;
    }
    final swept = Rect.fromPoints(start, end);
    ref.read(selectionProvider.notifier).marquee(_geometry.hitTestMarquee(swept), additive: _shift);
  }

  void _clearSession() {
    widget.overrides.value = const {};
    _rebuild(() {
      _session = null;
      _snapLines = const [];
      _pointerViewport = null;
      _cursor = MouseCursor.defer;
    });
  }
}
