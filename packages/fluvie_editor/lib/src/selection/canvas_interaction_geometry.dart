part of 'canvas_interaction.dart';

extension _CanvasInteractionGeometry on _CanvasInteractionState {
  ToolState get _toolState => ref.read(toolProvider);

  SceneGeometry get _geometry =>
      SceneGeometry.of(widget.document, widget.slide, enteredGroup: _entered);

  Size get _canvasSize {
    final size = widget.document.spec.size;
    return Size(size.width.toDouble(), size.height.toDouble());
  }

  /// The entered group, or null. Only a live top-level group of the mounted
  /// slide scopes editing; anything staler reads as not entered.
  String? get _entered {
    final id = ref.read(enteredGroupProvider);
    if (id == null) return null;
    if (widget.document.sceneOfElement(id) != widget.slide) return null;
    if (widget.document.elementJson(id)?['type'] != 'Group') return null;
    if (widget.document.parentGroupOf(id) != null) return null;
    return id;
  }

  /// The entered group's absolute box — the frame its children resolve
  /// against — or null at the top level.
  Rect? get _enteredFrame {
    final id = _entered;
    return id == null ? null : groupFrameRect(widget.document, id);
  }

  /// Where the active editing frame sits on the canvas (zero at top level).
  Offset get _frameOrigin => _enteredFrame?.topLeft ?? Offset.zero;

  /// The pixel space gizmo sessions work in: the slide, or the entered
  /// group's box.
  Size get _frameSize => _enteredFrame?.size ?? _canvasSize;

  // Not const: LogicalKeyboardKey has no primitive equality.
  static final Set<LogicalKeyboardKey> _shiftKeys = {
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
  };
  static final Set<LogicalKeyboardKey> _altKeys = {
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
  };

  // The snap-bypass modifier: Ctrl (Cmd on macOS). Shift and Alt already
  // mean aspect/additive and from-center; Space pans.
  static final Set<LogicalKeyboardKey> _snapBypassKeys = {
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
  };

  bool get _shift => HardwareKeyboard.instance.logicalKeysPressed.any(_shiftKeys.contains);

  bool get _alt => HardwareKeyboard.instance.logicalKeysPressed.any(_altKeys.contains);

  bool get _snapBypass =>
      HardwareKeyboard.instance.logicalKeysPressed.any(_snapBypassKeys.contains);

  /// The engine of one gesture over the selection [ids]: candidates are the
  /// other visible elements' rects (a group is one unit), plus the slide,
  /// the stored guides, and the grid. Null when snapping is off — and
  /// inside an entered group, whose children live in their own frame while
  /// guides and the grid live in the slide's (E17).
  SnapEngine? _snapperFor(Set<String> ids) {
    final prefs = ref.read(snapPreferencesProvider);
    if (!prefs.snapping || _entered != null) return null;
    final geometry = _geometry;
    final candidates = <Rect>[
      for (final id in widget.document.elementIdsInScene(widget.slide))
        if (!ids.contains(id) && widget.document.elementJson(id)?['visible'] != false)
          if (geometry.rectOf(id) case final Rect rect) rect,
    ];
    return SnapEngine(
      slide: _canvasSize,
      candidates: candidates,
      guides: ManualGuide.listFromJson(widget.document.sceneMeta(widget.slide)['guides']),
      gridSpacing: prefs.gridSpacing,
      tolerance: SnapEngine.defaultTolerance / widget.viewport.scale,
    );
  }

  bool get _panning =>
      HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.space);

  /// The single-selection gizmo geometry, or null (empty or multi
  /// selection, or an element without resolved geometry).
  GizmoGeometry? get _gizmo {
    final selected = ref.read(selectionProvider);
    if (selected.length != 1) return null;
    final id = selected.single;
    final rect = _geometry.rectOf(id);
    if (rect == null) return null;
    return GizmoGeometry(rect: rect, rotation: _geometry.rotationOf(id) ?? 0);
  }

  /// The element as the gizmo grabs it, or null without geometry. The rect
  /// is frame-local (identical to absolute at the top level), matching the
  /// stored placement's own frame of reference.
  GizmoTarget? _target(String id) {
    final rect = _geometry.rectOf(id);
    if (rect == null) return null;
    final transform = widget.document.elementJson(id)?['transform'];
    final placement = transform == null
        ? const Placement(x: 0.5, y: 0.5)
        : decodePlacement(transform);
    return (rect: rect.shift(-_frameOrigin), placement: placement);
  }

  Map<String, GizmoTarget> _targets(Iterable<String> ids) => {
    for (final id in ids)
      if (_target(id) case final GizmoTarget target) id: target,
  };
}
