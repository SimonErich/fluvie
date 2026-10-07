part of 'editor_screen.dart';

/// The media half of the editor screen: the asset reuse dialog, dropped
/// files, centered insertion of a picked source, and the media store's
/// bookkeeping around both.
extension _EditorScreenMedia on _EditorScreenState {
  /// Opens the deck-assets dialog; picking an entry inserts it (into
  /// [scene] when given, the current slide otherwise), and store entries
  /// can be removed in place.
  Future<void> _openAssets({int? scene}) => OiDialogShell.show<void>(
    context: context,
    semanticLabel: 'Deck assets',
    maxWidth: 420,
    minWidth: 280,
    builder: (close) => OiDialog.standard(
      label: 'Deck assets',
      title: 'Deck assets',
      content: OiFileDropTarget(
        dropMessage: 'Drop media to add it to the deck',
        onInternalDrop: (_, _) {},
        // coverage:ignore-start external drops need a real platform drag event and the pick and insert halves are unit tested via mediaPickFor and the asset panel
        onExternalDrop: (files) {
          if (files.isEmpty) return;
          unawaited(
            _insertDroppedFiles([
              for (final file in files) (name: file.name, bytes: file.bytes),
            ]),
          );
        },
        // coverage:ignore-end
        child: ListenableBuilder(
          listenable: _history,
          builder: (context, _) => AssetReusePanel(
            document: _history.document,
            onPick: (pick) {
              close(null);
              _insertPick(pick, scene: scene);
            },
            onImport: () {
              close(null);
              unawaited(_importAsset(scene: scene));
            },
            onCommand: _history.dispatch,
          ),
        ),
      ),
      onClose: () => close(null),
    ),
  );

  /// Records a fresh import in the media store, then drops [pick] centered
  /// on [scene] (the current slide by default) as an Image or Clip —
  /// except audio, which only the store holds.
  void _insertPick(MediaPick pick, {int? scene}) {
    final entry = storeEntryFor(_history.document, pick);
    if (entry != null) _history.dispatch(AddMediaEntryCommand(entry: entry));
    if (pick.isAudio) return;
    final size = _history.document.spec.size;
    final canvas = Size(size.width.toDouble(), size.height.toDouble());
    final bounds = Rect.fromCenter(
      center: canvas.center(Offset.zero),
      width: canvas.width * 0.4,
      height: canvas.height * 0.4,
    );
    final id = _history.document.nextId();
    _history.dispatch(
      InsertElementCommand(
        scene: scene ?? _slide,
        element: placeMediaIn(pick.source, bounds, canvas, isVideo: pick.isVideo),
        id: id,
      ),
    );
    _selectionScope.read(selectionProvider.notifier).select({id});
  }

  /// Picks a fresh file through the guarded importer, then inserts it
  /// centered on [scene] (the current slide by default) — the asset panel's
  /// Import control reusing the media tool's own pick-and-insert path. A
  /// cancelled pick, or a host with no importer wired, is a safe no-op.
  Future<void> _importAsset({int? scene}) async {
    final picks = await _pickMedia();
    if (!mounted) return;
    for (final pick in picks) {
      _insertPick(pick, scene: scene);
    }
  }

  /// Bin import does not choose a timeline position. Placement follows source
  /// inspection and writes its own single undoable range.
  Future<void> _importIntoBin() async {
    final picks = await _pickMedia();
    if (!mounted) return;
    picks.forEach(_recordBinPick);
  }

  Future<List<MediaPick>> _pickMedia() async {
    final importer = _selectionScope.read(mediaImporterProvider);
    if (importer == null) return const [];
    if (importer case final MultiMediaImporter multi) return multi.pickMediaMany();
    final pick = await importer.pickMedia();
    return pick == null ? const [] : [pick];
  }

  void _recordBinPick(MediaPick pick) {
    final entry = storeEntryFor(_history.document, pick);
    if (entry != null) _history.dispatch(AddMediaEntryCommand(entry: entry));
  }

  Future<void> _dropIntoBin(String name, Object? bytes) async {
    if (bytes is! List<int>) return;
    try {
      final pick = await mediaPickFor(name: name, bytes: bytes);
      if (pick != null && mounted) _recordBinPick(pick);
    } on Object catch (error) {
      _showImportRefused(error);
    }
  }

  /// Surfaces a refused import (the session media budget) as a dialog.
  void _showImportRefused(Object error) {
    if (!mounted) return;
    unawaited(_showFileMessage('Import refused', '$error'));
  }

  /// A file dropped onto the canvas: media inserts, anything else is left
  /// to the picker flows.
  // coverage:ignore-start reached only by a real platform drag event and its halves mediaPickFor insertPick and the refusal dialog are covered directly
  Future<void> _insertDropped(String name, Object? bytes) async {
    if (bytes is! List<int>) return;
    try {
      final pick = await mediaPickFor(name: name, bytes: bytes);
      if (pick == null || !mounted) return;
      _insertPick(pick);
    } on SessionMediaBudgetError catch (error) {
      _showImportRefused(error);
    }
  }

  Future<void> _insertDroppedFiles(List<({String name, Object? bytes})> files) async {
    for (final file in files) {
      await _insertDropped(file.name, file.bytes);
    }
  }

  // coverage:ignore-end
}

/// Wraps the media importer so a session-budget refusal becomes a visible
/// dialog instead of an unhandled error.
final class _GuardedMediaImporter implements MultiMediaImporter {
  _GuardedMediaImporter(this.inner, this.onRefused);

  final MediaImporter inner;
  final void Function(Object error) onRefused;

  @override
  Future<MediaPick?> pickMedia() async {
    try {
      return await inner.pickMedia();
    } on SessionMediaBudgetError catch (error) {
      onRefused(error);
      return null;
    }
  }

  @override
  Future<List<MediaPick>> pickMediaMany() async {
    try {
      if (inner case final MultiMediaImporter multi) return await multi.pickMediaMany();
      final pick = await inner.pickMedia();
      return pick == null ? const [] : [pick];
    } on SessionMediaBudgetError catch (error) {
      onRefused(error);
      return const [];
    }
  }
}
