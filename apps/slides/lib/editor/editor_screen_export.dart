// printVideoSpecJson is @experimental in fluvie_cli; the Dart export depends
// on it deliberately (the one supported spec-to-Dart printer).
// ignore_for_file: experimental_member_use
part of 'editor_screen.dart';

/// One export run's dialog handle: its live status and a dismisser.
typedef _ExportDialog = ({ValueNotifier<ExportStatus> status, VoidCallback close});

/// The editor's export flows: the printed Dart source, the rendered video,
/// and one PNG per slide (`Export .fluvie` is Save as and lives with the
/// file operations). Each long flow drives one [ExportProgressDialog].
extension _EditorScreenExport on _EditorScreenState {
  /// The deck name without its `.fluvie` extension — what the export
  /// artifacts are named after.
  String get _exportBaseName {
    for (final extension in const ['.fluvie', '.json']) {
      if (_name.endsWith(extension)) return _name.substring(0, _name.length - extension.length);
    }
    return _name;
  }

  /// Prints the document as runnable Dart (the fluvie_cli printer: theme
  /// tokens resolve to literals, masters apply, steps and notes get a
  /// heads-up comment) and writes it through the copy channel — the open
  /// document never retargets.
  Future<void> _exportDart() async {
    final source = printVideoSpecJson(_history.document.toJson()..remove('editor'));
    await _saver.saveCopy(suggestedName: '$_exportBaseName.dart', contents: source);
  }

  /// Renders the deck to an MP4 through the platform render service, with
  /// the service's phase lines in the progress dialog.
  ///
  /// The options dialog comes first: resolution and quality steer this one run,
  /// while a changed frame rate is applied to the document first, because a
  /// deck's timeline is measured in its own frames and cannot be captured at a
  /// rate it was not authored at. Dismissing the options dialog cancels
  /// without starting anything. A cancelled output pick closes quietly; a
  /// render failure lands in the progress dialog.
  Future<void> _exportVideo() async {
    final choice = await showExportVideoDialog(
      context,
      spec: _history.document.spec,
      advanced: _workspace == EditorWorkspace.deliver,
    );
    if (choice == null) return;
    if (choice.fps != _history.document.spec.fps) {
      _history.dispatch(UpdateVideoCommand(patch: {'fps': choice.fps}));
    }
    if (!mounted) return;
    final job = _enqueueVideo(choice.options);
    final dialog = _showExportDialog(
      'Export video',
      onCancel: () => _renderQueue.cancel(job.id),
      background: true,
    );
    void update() {
      dialog.status.value = switch (job.phase) {
        RenderQueuePhase.queued || RenderQueuePhase.running => ExportRunning(job.message),
        RenderQueuePhase.complete => ExportDone('Rendered to ${job.artifact}'),
        RenderQueuePhase.failed => ExportFailed('The render failed: ${job.message}'),
        RenderQueuePhase.cancelled => ExportFailed(job.message),
      };
      if (job.phase != RenderQueuePhase.running && job.phase != RenderQueuePhase.queued) {
        _renderQueue.removeListener(update);
        if (job.artifact == null && job.message == 'Output selection cancelled.') dialog.close();
      }
    }

    _renderQueue.addListener(update);
    update();
  }

  /// Renders every slide's settled state through the hidden full-size
  /// stage and encodes each to PNG, reporting progress into [dialog] — the
  /// shared front half of the image and PDF exports.
  Future<List<Uint8List>> _renderSlidePngs(_ExportDialog dialog) async {
    final count = _history.document.sceneCount;
    final images = <Uint8List>[];
    for (var slide = 0; slide < count; slide++) {
      dialog.status.value = ExportRunning('Rendering slide ${slide + 1} of $count');
      final image = await _renderExportSlide(slide, count);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) {
        // coverage:ignore-start defensive engine guard toByteData returns data for a healthy boundary
        throw StateError('the slide image read-back returned no data');
        // coverage:ignore-end
      }
      images.add(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    }
    return images;
  }

  /// Renders one slide on the hidden export stage.
  ///
  /// Closing the deck mid-export takes that stage with it, so a stage that
  /// is already gone — and a render that fails once the editor is gone —
  /// ends the export saying so. The alternative is a null unwrap reported
  /// into a dialog that outlives the editor and would show a type error.
  Future<ui.Image> _renderExportSlide(int slide, int count) async {
    final stage = _exportStage.currentState;
    if (stage == null) {
      // coverage:ignore-line only reached when the deck closes while a slide png encodes
      throw _deckClosed(slide, count);
    }
    try {
      return await stage.render(slide);
    } on Object catch (error, stackTrace) {
      if (mounted) Error.throwWithStackTrace(error, stackTrace);
      throw _deckClosed(slide, count);
    }
  }

  StateError _deckClosed(int slide, int count) =>
      StateError('the deck closed before slide ${slide + 1} of $count finished exporting');

  /// Renders every slide to a PNG and hands the lot to the platform
  /// exporter (a folder pick on desktop, downloads on the web).
  Future<void> _exportImages() async {
    final dialog = _showExportDialog('Export slide images');
    try {
      final images = await _renderSlidePngs(dialog);
      final target = await _images.saveImages(baseName: _exportBaseName, images: images);
      if (target == null) {
        dialog.close();
        return;
      }
      dialog.status.value = ExportDone('Saved ${images.length} images to $target');
    } on Object catch (error) {
      dialog.status.value = ExportFailed('The image export failed: $error');
    }
  }

  /// Renders every slide to a PNG, embeds one per page at the deck's
  /// canvas size, and writes the single PDF through the saver's copy-bytes
  /// channel — the open document never retargets.
  Future<void> _exportPdf() async {
    final dialog = _showExportDialog('Export PDF');
    try {
      final images = await _renderSlidePngs(dialog);
      dialog.status.value = const ExportRunning('Building the PDF');
      final size = _history.document.spec.size;
      final bytes = await buildSlidePdf(
        images: images,
        width: size.width.toDouble(),
        height: size.height.toDouble(),
      );
      final name = await _saver.saveCopyBytes(
        suggestedName: '$_exportBaseName.pdf',
        bytes: bytes,
      );
      if (name == null) {
        dialog.close();
        return;
      }
      dialog.status.value = ExportDone('Saved $name');
    } on Object catch (error) {
      dialog.status.value = ExportFailed('The PDF export failed: $error');
    }
  }

  /// Opens the shared progress dialog and returns its live handle.
  _ExportDialog _showExportDialog(String title, {VoidCallback? onCancel, bool background = false}) {
    final status = ValueNotifier<ExportStatus>(const ExportRunning('Preparing'));
    void Function(void)? closer;
    unawaited(
      OiDialogShell.show<void>(
        context: context,
        semanticLabel: title,
        maxWidth: 480,
        minWidth: 280,
        builder: (close) {
          closer = close;
          return ExportProgressDialog(
            title: title,
            status: status,
            onClose: () => close(null),
            onCancel: onCancel,
            allowBackground: background,
          );
        },
      ),
    );
    return (status: status, close: () => closer?.call(null));
  }
}
