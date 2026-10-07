part of 'editor_screen.dart';

extension _EditorScreenPreviewStatus on _EditorScreenState {
  Widget _filmstripStatus() => ListenableBuilder(
    listenable: _filmstrips,
    builder: (context, _) {
      final error = _filmstrips.error;
      if (error == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Expanded(child: OiLabel.small(error)),
            OiButton.ghost(label: 'Retry filmstrip', onTap: _filmstrips.retry),
          ],
        ),
      );
    },
  );

  Widget _audioStatus() => ListenableBuilder(
    listenable: _audioPreview,
    builder: (context, _) {
      final error = _audioPreview.error;
      if (error != null) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(child: OiLabel.small('Audio preview unavailable: $error')),
              OiButton.ghost(label: 'Retry audio', onTap: _audioPreview.retry),
            ],
          ),
        );
      }
      if (_audioPreview.loading) {
        return const Padding(
          padding: EdgeInsets.all(4),
          child: OiLabel.small('Preparing audio preview…'),
        );
      }
      return const SizedBox.shrink();
    },
  );
}
