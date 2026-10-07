part of 'canvas_interaction.dart';

/// The canvas overlay stack: selection chrome, the gizmo, snap guides, the
/// floating toolbar, the marquee, the inline text editor, and the rulers.
extension _CanvasLayers on _CanvasInteractionState {
  List<Widget> _layers(Set<String> selected, GizmoSession? session) {
    final marquee = _marqueeViewportRect;
    final textEdit = _textEdit;

    // While dragging, the gizmo and the content follow the live placements;
    // the chrome's document-based outlines pause for the dragged ids.
    Rect? gizmoRect;
    var gizmoRotation = 0.0;
    if (selected.length == 1) {
      final id = selected.single;
      // Session rects are frame-local; the overlay draws in canvas space.
      gizmoRect = session?.displayRectOf(id)?.shift(_frameOrigin) ?? _geometry.rectOf(id);
      gizmoRotation = session != null && session.live.containsKey(id)
          ? session.displayRotationOf(id)
          : (_geometry.rotationOf(id) ?? 0);
    }
    final chromeSelected = session == null
        ? selected
        : selected.difference(session.live.keys.toSet());

    return [
      if (widget.document.sceneMasterName(widget.slide) != null)
        MasterSlotOverlay(
          document: widget.document,
          slide: widget.slide,
          viewport: widget.viewport,
        ),
      SelectionChrome(
        geometry: _geometry,
        viewport: widget.viewport,
        selected: chromeSelected,
        hovered: _session == null ? _hovered : null,
      ),
      if (gizmoRect != null)
        TransformGizmo(
          rect: gizmoRect,
          rotation: gizmoRotation,
          viewport: widget.viewport,
          label: session?.label,
          labelAnchor: _pointerViewport,
        ),
      if (session != null) SnapGuideOverlay(lines: _snapLines, viewport: widget.viewport),
      if (widget.document.elementIdsInScene(widget.slide).isEmpty &&
          widget.document.sceneMasterName(widget.slide) == null)
        IgnorePointer(
          child: Center(
            child: OiLabel.body(
              'An empty slide. Press T for text, R for a rectangle, '
              'or drop media anywhere.',
              color: context.colors.textSubtle,
            ),
          ),
        ),
      // The whole-document preview parked mid-transition: the scene is
      // displaced, so editing waits for its settled frame.
      if (!_sceneSettled)
        IgnorePointer(
          child: Center(
            child: OiLabel.body(
              'Scrub to the settled frame to edit',
              color: context.colors.textSubtle,
            ),
          ),
        ),
      if (gizmoRect != null && session == null && textEdit == null)
        Positioned.fromRect(
          rect: Rect.fromPoints(
            widget.viewport.toViewport(gizmoRect.topLeft),
            widget.viewport.toViewport(gizmoRect.bottomRight),
          ),
          child: OiFloating(
            visible: true,
            alignment: OiFloatingAlignment.topCenter,
            gap: 10,
            anchor: const SizedBox.expand(),
            child: SelectionToolbar(
              element: widget.document.elementJson(selected.single) ?? const {},
              onPatch: (patch) => _patchSelected(selected.single, patch),
              onDelete: () => _deleteSelected(selected.single),
            ),
          ),
        ),
      if (marquee != null) MarqueeOverlay(rect: marquee),
      if (textEdit != null && _textEditRect(textEdit.id) != null)
        Positioned.fromRect(
          rect: _textEditRect(textEdit.id)!,
          child: InlineTextEditor(
            key: ValueKey('edit-${textEdit.id}'),
            initialText: textEdit.initial,
            style: _textEditStyle(textEdit.id),
            onCommit: _commitTextEdit,
            onCancel: () => _rebuild(() => _textEdit = null),
          ),
        ),
      if (_slotEdit != null && _slotEditRect(_slotEdit!) != null)
        Positioned.fromRect(
          rect: _slotEditRect(_slotEdit!)!,
          child: InlineTextEditor(
            key: ValueKey('slot-$_slotEdit'),
            initialText: '',
            style: _slotEditStyle(_slotEdit!),
            onCommit: _commitSlotFill,
            onCancel: () => _rebuild(() => _slotEdit = null),
          ),
        ),
      if (ref.watch(snapPreferencesProvider).rulers) _guideLayer(),
    ];
  }
}
