part of 'canvas_interaction.dart';

final class _CanvasInteractionState extends ConsumerState<CanvasInteraction> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'canvas');
  Offset? _marqueeStart;
  Offset? _marqueeEnd;
  String? _hovered;
  GizmoSession? _session;
  List<SnapLine> _snapLines = const [];
  MouseCursor _cursor = MouseCursor.defer;
  Offset? _pointerViewport;
  ({String id, String initial})? _textEdit;
  String? _slotEdit;
  String? _lastTapId;
  int _lastTapMs = 0;
  late bool _settled = _sceneSettled;

  /// The gesture handlers live in `canvas_gestures.dart`; this shim keeps
  /// `setState` inside the class.
  void _rebuild(VoidCallback change) => setState(change);

  @override
  void initState() {
    super.initState();
    _settled = _sceneSettled;
    // The floating toolbar tracks the selection across pans and zooms.
    widget.viewport.addListener(_onViewport);
    // In the whole-document preview the settled state flips as the playhead
    // crosses the scene's settle frame, showing or hiding the edit gate.
    widget.transport?.frames.addListener(_onTransportFrame);
  }

  @override
  void didUpdateWidget(CanvasInteraction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transport != widget.transport) {
      oldWidget.transport?.frames.removeListener(_onTransportFrame);
      widget.transport?.frames.addListener(_onTransportFrame);
    }
    // A new scene (or clock) can flip the settled state without a frame tick.
    _settled = _sceneSettled;
  }

  @override
  void dispose() {
    widget.viewport.removeListener(_onViewport);
    widget.transport?.frames.removeListener(_onTransportFrame);
    _focusNode.dispose();
    super.dispose();
  }

  void _onViewport() => setState(() {});

  void _onTransportFrame() {
    if (_sceneSettled != _settled) setState(() => _settled = _sceneSettled);
  }

  /// Whether the on-stage scene is settled at the current frame — always
  /// true outside the whole-document preview, and true there once the
  /// transport reaches [CanvasInteraction.settleFrame]. Below it the scene
  /// still carries the compositor's transition displacement the geometry
  /// never sees, so the input layer stays inert (a drag on the stale gizmo
  /// would grab empty space and commit a corrupt placement).
  bool get _sceneSettled {
    final transport = widget.transport;
    return transport == null || transport.frame >= widget.settleFrame;
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectionProvider);
    final tool = ref.watch(toolProvider);
    ref
      // Entering or leaving a group rescopes geometry and hit-testing.
      ..watch(enteredGroupProvider)
      ..listen<ToolState>(toolProvider, (previous, next) {
        if (next.tool == EditorTool.media && previous?.tool != EditorTool.media) {
          unawaited(_pickMedia());
        }
      });
    final session = _session;
    final cursor = switch (tool.tool) {
      EditorTool.hand => SystemMouseCursors.grab,
      EditorTool.select => _cursor,
      _ => SystemMouseCursors.precise,
    };
    // The palette host wraps the whole surface (its shortcut scope catches
    // Ctrl/Cmd+K above the canvas focus); the context menu sits between the
    // hover tracking (which names its target) and the canvas gestures.
    return EditorCommandPalette(
      scopeBuilder: _commandScope,
      onDismissed: _focusNode.requestFocus,
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKeyEvent,
        child: MouseRegion(
          cursor: cursor,
          onHover: _onHover,
          onExit: (_) => setState(() {
            _hovered = null;
            _cursor = MouseCursor.defer;
          }),
          child: ContextMenuHost(
            label: 'Canvas menu',
            enabled: session == null && _textEdit == null && _slotEdit == null,
            itemsAt: _contextMenuItemsAt,
            child: DragTarget<EffectDragData>(
              onWillAcceptWithDetails: (_) => widget.onCommand != null,
              onAcceptWithDetails: _onEffectDrop,
              builder: (context, _, _) => GestureDetector(
                behavior: HitTestBehavior.translucent,
                // The marquee anchors where the pointer went down, not where
                // the recognizer won the arena.
                dragStartBehavior: DragStartBehavior.down,
                onTapUp: _onTapUp,
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: Stack(fit: StackFit.expand, children: _layers(selected, session)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
