part of 'slides_app.dart';

/// The crash-recovery half of opening a deck for editing: when the
/// autosave store holds a version of the deck that differs from the file
/// being opened, ask before starting the editor. Lives outside the state
/// class, like the recents bookkeeping.
extension _SlidesAppRecovery on _SlidesAppState {
  /// The autosaved document to open instead of [opened], or null to open
  /// [opened] itself. Prompts only when a readable autosave under [key]
  /// differs from the opened document: Recover returns the autosave (its
  /// sidecar media adopted into the session first, so previews rebuild),
  /// Discard deletes it, dismissing keeps it for next time. An autosave
  /// referencing session media neither the sidecar nor the session holds
  /// cannot open safely; its prompt names the missing values and offers
  /// only Keep or Discard. Store failures and unreadable records read as
  /// "no autosave" — recovery must never block an open.
  Future<EditorDocument?> _maybeRecover(String key, String title, EditorDocument opened) async {
    final AutosaveSnapshot? snapshot;
    try {
      snapshot = await _autosave.read(key);
    } on Object {
      return null;
    }
    if (snapshot == null) return null;
    final EditorDocument candidate;
    try {
      candidate = EditorDocument.fromJson(parseRawJson(snapshot.record.json));
    } on Object {
      return null;
    }
    if (candidate.documentDigest == opened.documentDigest) return null;
    final missing =
        documentBundleValues(candidate)
            .where(
              (value) =>
                  !snapshot!.media.containsKey(value) && _sessionMedia.bytesFor(value) == null,
            )
            .toList()
          ..sort();
    final savedAt = snapshot.record.savedAt;
    final promptContext = _startScreenKey.currentContext;
    if (promptContext == null || !promptContext.mounted) return null;
    if (missing.isNotEmpty) {
      // The web reality: localStorage kept the record but cannot keep media
      // bytes, and this session does not hold them either — opening would
      // break every reference. Say exactly what is needed instead.
      final discard = await OiDialogShell.show<bool>(
        context: promptContext,
        semanticLabel: 'Autosave needs its media',
        maxWidth: 480,
        minWidth: 280,
        builder: (close) => OiDialog.standard(
          label: 'Autosave needs its media',
          title: 'Autosave needs its media',
          content: OiLabel.body(
            '"$title" has an autosaved version from '
            '${relativeTimeLabel(savedAt, DateTime.now())}, but it references '
            'imported media this session does not hold: ${missing.join(', ')}. '
            'Open the deck bundle that contains that media to recover it '
            'there, or discard the autosave.',
          ),
          actions: [
            OiButton.secondary(label: 'Discard', onTap: () => close(true)),
            OiButton.primary(label: 'Keep autosave', onTap: () => close(false)),
          ],
          onClose: () => close(false),
        ),
      );
      if (discard ?? false) {
        try {
          await _autosave.clear(key);
        } on Object {
          // Best-effort by contract.
        }
      }
      return null;
    }
    final recover = await OiDialogShell.show<bool>(
      context: promptContext,
      semanticLabel: 'Recover unsaved changes?',
      maxWidth: 480,
      minWidth: 280,
      builder: (close) => OiDialog.standard(
        label: 'Recover unsaved changes?',
        title: 'Recover unsaved changes?',
        content: OiLabel.body(
          '"$title" has an autosaved version from '
          '${relativeTimeLabel(savedAt, DateTime.now())}.',
        ),
        actions: [
          OiButton.secondary(label: 'Discard', onTap: () => close(false)),
          OiButton.primary(label: 'Recover', onTap: () => close(true)),
        ],
        onClose: () => close(),
      ),
    );
    // Dismissed: keep the autosave for next time and open the file.
    if (recover == null) return null;
    if (!recover) {
      try {
        await _autosave.clear(key);
      } on Object {
        // Best-effort by contract.
      }
      return null;
    }
    // The sidecar's media restores the session before the editor mounts, so
    // the recovered previews build (best-effort like the rest of autosave).
    try {
      await _sessionMedia.adopt(snapshot.media);
    } on Object {
      // A refused adopt leaves the session as it was.
    }
    return candidate;
  }
}
