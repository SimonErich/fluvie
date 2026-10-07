part of 'editor_screen.dart';

extension _EditorScreenDelivery on _EditorScreenState {
  RenderQueueJob<_QueuedVideo> _enqueueVideo(ExportOptions options, {String? suffix}) =>
      _renderQueue.add(
        label: '${options.longEdge}px long edge · ${options.codec.name}',
        payload: (
          spec: _history.document.spec,
          options: options,
          name: '$_exportBaseName${suffix == null ? "" : "-$suffix"}.mp4',
        ),
      );

  Widget _deliveryPanel() => ListenableBuilder(
    listenable: _renderQueue,
    builder: (context, _) => SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const OiLabel.body('Render queue'),
            const SizedBox(height: 8),
            OiButton.primary(
              label: 'Add export',
              fullWidth: true,
              enabled: _render.isAvailable,
              onTap: _render.isAvailable ? () => unawaited(_exportVideo()) : null,
            ),
            const SizedBox(height: 6),
            OiButton.secondary(
              label: 'Batch 1080p + 720p',
              fullWidth: true,
              enabled: _render.isAvailable,
              onTap: _render.isAvailable
                  ? () {
                      _enqueueVideo(const ExportOptions(longEdge: 1920), suffix: '1080p');
                      _enqueueVideo(const ExportOptions(longEdge: 1280), suffix: '720p');
                    }
                  : null,
            ),
            if (!_render.isAvailable) OiLabel.small(_render.unavailableNote),
            const SizedBox(height: 12),
            if (_renderQueue.jobs.isEmpty)
              const OiLabel.small(
                'Queued exports use a snapshot of your project. You can keep editing.',
              ),
            for (final job in _renderQueue.jobs)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OiLabel.body(job.label),
                    OiLabel.small(job.message),
                    if (job.phase == RenderQueuePhase.queued ||
                        job.phase == RenderQueuePhase.running)
                      OiButton.ghost(
                        label: 'Cancel ${job.id}',
                        onTap: () => _renderQueue.cancel(job.id),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Future<String?> _importLut() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['cube'],
      withData: true,
    );
    final bytes = result?.files.firstOrNull?.bytes;
    if (bytes == null) return null;
    // Inline LUTs are portable, but a text file should not exhaust the editor.
    if (bytes.length > 4 * 1024 * 1024) {
      throw const FormatException('Choose a .cube file no larger than 4 MiB.');
    }
    return utf8.decode(bytes);
  }
}
