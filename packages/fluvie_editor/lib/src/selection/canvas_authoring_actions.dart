part of 'canvas_interaction.dart';

/// Document-authoring actions shared by pointer input and editing chrome.
/// Placement, media, text, guides and nudges keep their original command flow.
extension _CanvasAuthoringActions on _CanvasInteractionState {
  /// Inserts what a click of a placing [tool] produces at [point].
  void _placeAt(ToolState tool, Offset point) {
    final json = placeElementAt(tool, point, _canvasSize);
    if (json != null) _insertPlaced(json, editText: tool.tool == EditorTool.text);
  }

  /// Inserts what a drag of a placing [tool] from [start] to [end] produces.
  void _placeFromDrag(ToolState tool, Offset start, Offset end) {
    if ((end - start).distance < 4) {
      _placeAt(tool, start);
      return;
    }
    final json = placeElementIn(
      tool,
      Rect.fromPoints(start, end),
      _canvasSize,
      from: start,
      to: end,
    );
    if (json != null) _insertPlaced(json, editText: tool.tool == EditorTool.text);
  }

  /// Dispatches the insert, selects the new element, and resets the tool.
  void _insertPlaced(Map<String, Object?> json, {bool editText = false}) {
    final id = widget.document.nextId();
    widget.onCommand?.call(InsertElementCommand(scene: widget.slide, element: json, id: id));
    ref.read(selectionProvider.notifier).select({id});
    ref.read(toolProvider.notifier).reset();
    _rebuild(() {
      if (editText) _textEdit = (id: id, initial: json['text'] as String? ?? '');
    });
  }

  /// The media tool: ask the injected importer, record a fresh import in the
  /// media store, and drop the pick centered — except audio, which only the
  /// store holds (the timeline's tracks offer it, never the canvas).
  Future<void> _pickMedia() async {
    final importer = ref.read(mediaImporterProvider);
    if (importer == null) {
      ref.read(toolProvider.notifier).reset();
      return;
    }
    final pick = await importer.pickMedia();
    if (!mounted) return;
    if (pick == null) {
      ref.read(toolProvider.notifier).reset();
      return;
    }
    final entry = storeEntryFor(widget.document, pick);
    if (entry != null) widget.onCommand?.call(AddMediaEntryCommand(entry: entry));
    if (pick.isAudio) {
      ref.read(toolProvider.notifier).reset();
      return;
    }
    final canvas = _canvasSize;
    final bounds = Rect.fromCenter(
      center: canvas.center(Offset.zero),
      width: canvas.width * 0.4,
      height: canvas.height * 0.4,
    );
    _insertPlaced(placeMediaIn(pick.source, bounds, canvas, isVideo: pick.isVideo));
  }

  /// The inline editor's box over element [id], in viewport pixels.
  Rect? _textEditRect(String id) {
    final rect = _geometry.rectOf(id);
    if (rect == null) return null;
    return Rect.fromPoints(
      widget.viewport.toViewport(rect.topLeft),
      widget.viewport.toViewport(rect.bottomRight),
    );
  }

  /// The element's text style scaled to viewport pixels.
  TextStyle _textEditStyle(String id) {
    final style = widget.document.elementJson(id)?['style'];
    final fontSize = style is Map<String, Object?> && style['fontSize'] is num
        ? (style['fontSize']! as num).toDouble()
        : 32.0;
    return TextStyle(color: const Color(0xFFF9FAFB), fontSize: fontSize * widget.viewport.scale);
  }

  void _commitTextEdit(String text) {
    final edit = _textEdit;
    if (edit == null) return;
    final element = widget.document.elementJson(edit.id);
    if (element != null && element['text'] != text) {
      widget.onCommand?.call(
        ReplaceElementCommand(id: edit.id, element: {...element, 'text': text}),
      );
    }
    _rebuild(() => _textEdit = null);
  }

  /// The ruler-and-guide surface (mounted while the rulers are on): guide
  /// edits commit through the command layer, so undo applies.
  Widget _guideLayer() => GuideLayer(
    viewport: widget.viewport,
    slideSize: _canvasSize,
    guides: ManualGuide.listFromJson(widget.document.sceneMeta(widget.slide)['guides']),
    onGuidesChanged: (guides) => widget.onCommand?.call(
      SetSceneMetaCommand(index: widget.slide, meta: {'guides': ManualGuide.listToJson(guides)}),
    ),
  );

  /// A floating-toolbar patch: content keys merged over the element.
  void _patchSelected(String id, Map<String, Object?> patch) {
    final element = widget.document.elementJson(id);
    if (element == null) return;
    widget.onCommand?.call(ReplaceElementCommand(id: id, element: {...element, ...patch}));
  }

  /// Deletes the selected element and clears the selection.
  void _deleteSelected(String id) {
    widget.onCommand?.call(RemoveElementCommand(id: id));
    ref.read(selectionProvider.notifier).clear();
  }

  /// One arrow press: a canvas-pixel step (10 with Shift) written as a
  /// coalescing command, so a run of nudges undoes as one.
  KeyEventResult _nudge(Offset direction) {
    if (!_sceneSettled) return KeyEventResult.ignored;
    final targets = _targets(ref.read(selectionProvider));
    if (targets.isEmpty) return KeyEventResult.ignored;
    final placements = TransformDrag.movedBy(targets, direction * (_shift ? 10 : 1), _frameSize);
    widget.onCommand?.call(
      SetTransformsCommand(
        transforms: {
          for (final entry in placements.entries) entry.key: encodePlacement(entry.value),
        },
        mergeGroup: 'nudge',
      ),
    );
    return KeyEventResult.handled;
  }
}
