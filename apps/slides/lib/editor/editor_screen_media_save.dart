part of 'editor_screen.dart';

/// The media-save choice: bundle or plain JSON, optionally remembered for
/// this deck.
typedef _MediaSaveChoice = ({bool bundle, bool remember});

/// The dialogs of the media-aware save flow: the suppressible session-media
/// warning, the media-less-copy confirm, and the plain message box.
extension _EditorScreenMediaSave on _EditorScreenState {
  /// Asks how a deck referencing [count] imported media files should save.
  /// Returns null on Cancel.
  Future<_MediaSaveChoice?> _askMediaSave(int count) {
    var remember = false;
    final files = count == 1 ? '1 imported media file' : '$count imported media files';
    return OiDialogShell.show<_MediaSaveChoice>(
      context: context,
      semanticLabel: 'Save imported media?',
      maxWidth: 640,
      minWidth: 320,
      builder: (close) => OiDialog.standard(
        label: 'Save imported media?',
        title: 'Save imported media?',
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OiLabel.body(
                'This deck references $files. A plain .fluvie JSON cannot '
                'carry them; a bundle packs the deck and its media into one '
                'file.',
              ),
              const SizedBox(height: 12),
              OiCheckbox(
                value: remember,
                label: "Don't ask again for this deck",
                onChanged: (value) => setState(() => remember = value),
              ),
            ],
          ),
        ),
        actions: [
          OiButton.secondary(label: 'Cancel', onTap: () => close(null)),
          OiButton.secondary(
            label: 'Save JSON only',
            onTap: () => close((bundle: false, remember: remember)),
          ),
          OiButton.primary(
            label: 'Save bundle',
            onTap: () => close((bundle: true, remember: remember)),
          ),
        ],
        onClose: () => close(null),
      ),
    );
  }

  /// Confirms writing a plain-JSON copy of a deck whose media lives in the
  /// session. Returns true to write anyway.
  Future<bool?> _confirmMediaLessCopy() => OiDialogShell.show<bool>(
    context: context,
    semanticLabel: 'Copy without media?',
    maxWidth: 520,
    minWidth: 320,
    builder: (close) => OiDialog.standard(
      label: 'Copy without media?',
      title: 'Copy without media?',
      content: const OiLabel.body(
        'A copy saves as plain .fluvie JSON and will not carry the imported '
        'media. Use Save to write a bundle that keeps it.',
      ),
      actions: [
        OiButton.secondary(label: 'Cancel', onTap: () => close(false)),
        OiButton.primary(label: 'Save copy anyway', onTap: () => close(true)),
      ],
      onClose: () => close(false),
    ),
  );

  /// One informational message box with an OK action.
  Future<void> _showFileMessage(String title, String message) => OiDialogShell.show<void>(
    context: context,
    semanticLabel: title,
    maxWidth: 520,
    minWidth: 320,
    builder: (close) => OiDialog.standard(
      label: title,
      title: title,
      content: OiLabel.body(message),
      actions: [OiButton.primary(label: 'OK', onTap: () => close(null))],
      onClose: () => close(null),
    ),
  );
}
