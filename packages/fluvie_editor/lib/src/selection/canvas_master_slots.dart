part of 'canvas_interaction.dart';

/// The master-slot half of the canvas input: clicking an unfilled slot on
/// an adopting slide starts the matching fill flow — text slots type
/// straight into a new fill through the inline editor, media slots ask the
/// injected importer — and the fill lands as one [FillSlotCommand].
extension _CanvasMasterSlots on _CanvasInteractionState {
  /// Consumes a tap at [canvasPoint] when it lands on an unfilled slot.
  bool _handleSlotTap(Offset canvasPoint) {
    if (widget.onCommand == null) return false;
    for (final entry in unfilledSlotRects(widget.document, widget.slide).entries) {
      if (!entry.value.contains(canvasPoint)) continue;
      if (slotPrefersMedia(entry.key)) {
        unawaited(_fillMediaSlot(entry.key));
      } else {
        _rebuild(() => _slotEdit = entry.key);
      }
      return true;
    }
    return false;
  }

  /// The inline editor's box over the unfilled [slot], in viewport pixels.
  Rect? _slotEditRect(String slot) {
    final rect = unfilledSlotRects(widget.document, widget.slide)[slot];
    if (rect == null) return null;
    return Rect.fromPoints(
      widget.viewport.toViewport(rect.topLeft),
      widget.viewport.toViewport(rect.bottomRight),
    );
  }

  /// The slot's text style scaled to viewport pixels (the placeholder's
  /// `fontSize` when it declares a literal one).
  TextStyle _slotEditStyle(String slot) {
    final slots = widget.document.masterSlots(widget.slide);
    final style = [
      for (final entry in slots)
        if (entry.slot == slot) entry.style,
    ].firstOrNull;
    final fontSize = style?['fontSize'];
    return TextStyle(
      color: const Color(0xFFF9FAFB),
      fontSize: (fontSize is num ? fontSize.toDouble() : 32.0) * widget.viewport.scale,
    );
  }

  /// Commits the typed text as the slot's fill — one undo step. Empty text
  /// abandons the flow and the slot stays unfilled.
  void _commitSlotFill(String text) {
    final slot = _slotEdit;
    if (slot == null) return;
    if (text.isNotEmpty) {
      final id = widget.document.nextId();
      widget.onCommand?.call(
        FillSlotCommand(
          slide: widget.slide,
          slot: slot,
          id: id,
          element: {'type': 'Text', 'text': text},
        ),
      );
      ref.read(selectionProvider.notifier).select({id});
    }
    _rebuild(() => _slotEdit = null);
  }

  /// Fills a media slot through the injected importer. The fill carries no
  /// transform — the placeholder places it.
  Future<void> _fillMediaSlot(String slot) async {
    final importer = ref.read(mediaImporterProvider);
    if (importer == null) return;
    final pick = await importer.pickMedia();
    if (!mounted || pick == null) return;
    final id = widget.document.nextId();
    widget.onCommand?.call(
      FillSlotCommand(
        slide: widget.slide,
        slot: slot,
        id: id,
        element: {
          'type': pick.isVideo ? 'Clip' : 'Image',
          'source': Map<String, Object?>.of(pick.source),
          'fit': 'cover',
        },
      ),
    );
    ref.read(selectionProvider.notifier).select({id});
  }
}
