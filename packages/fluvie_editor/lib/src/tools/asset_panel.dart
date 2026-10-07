import 'package:flutter/widgets.dart';
import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/media/media_store_entry.dart';
import 'package:fluvie_editor/src/tools/media_importer.dart';
import 'package:fluvie_editor/src/tools/media_scan.dart';
import 'package:fluvie_editor/src/widgets/editor_tip.dart';
import 'package:obers_ui/obers_ui.dart';

/// The deck's media, listed for reuse: every store entry (imports the
/// document tracks) plus any referenced source the store does not hold,
/// once each. Tapping an image or video hands it back for insertion; audio
/// waits for the timeline's tracks.
final class AssetReusePanel extends StatelessWidget {
  /// Lists [document]'s media; [onPick] receives the chosen source. Pass
  /// [onCommand] to offer removing store entries, and [onImport] to offer an
  /// Import control that brings a fresh file into the deck.
  const AssetReusePanel({
    required this.document,
    required this.onPick,
    this.onCommand,
    this.onImport,
    super.key,
  });

  /// The deck being scanned.
  final EditorDocument document;

  /// Receives the picked source for insertion.
  final void Function(MediaPick pick) onPick;

  /// Receives the store's remove commands; null hides the remove controls.
  final void Function(EditorCommand command)? onCommand;

  /// Brings a fresh file into the deck; null hides the Import control.
  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context) {
    final entries = document.mediaEntries;
    final stored = {
      for (final entry in entries) '${entry.source['kind']}|${entry.source['value']}',
    };
    final picks = usedMediaSources(document)
        .where((pick) => !stored.contains('${pick.source['kind']}|${pick.source['value']}'))
        .toList(growable: false);
    if (entries.isEmpty && picks.isEmpty) return _emptyState(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onImport != null) _importButton(),
        for (final entry in entries) _entryTile(entry),
        for (final pick in picks)
          OiListTile(
            title: _name(pick),
            subtitle: '${pick.source['kind']} · ${pick.isVideo ? 'video' : 'image'}',
            onTap: () => onPick(pick),
          ),
      ],
    );
  }

  /// The empty panel: the Import affordance when the host offers one,
  /// otherwise the media-tool hint.
  Widget _emptyState(BuildContext context) {
    if (onImport == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: OiLabel.body(
          'No media in this deck yet. Insert an image or video with the media tool.',
          color: context.colors.textSubtle,
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: OiLabel.body(
            'Drag files here, or import one to add media to the deck.',
            color: context.colors.textSubtle,
          ),
        ),
        _importButton(),
      ],
    );
  }

  /// The Import control, shared by the populated and empty panels.
  Widget _importButton() => Padding(
    padding: const EdgeInsets.all(8),
    child: OiButton.outline(
      label: 'Import media',
      icon: OiIcons.cloudUpload,
      size: OiButtonSize.small,
      fullWidth: true,
      onTap: onImport,
    ),
  );

  Widget _entryTile(MediaStoreEntry entry) {
    final onCommand = this.onCommand;
    return OiListTile(
      title: entry.name,
      subtitle: '${entry.source['kind']} · ${entry.kind.name}',
      onTap: entry.kind == MediaStoreKind.audio
          ? null
          : () => onPick(
              MediaPick(
                source: Map<String, Object?>.of(entry.source),
                isVideo: entry.kind == MediaStoreKind.video,
              ),
            ),
      trailing: onCommand == null
          ? null
          : EditorTip(
              message: 'Remove ${entry.name}',
              child: OiIconButton(
                icon: OiIcons.trash,
                semanticLabel: 'Remove ${entry.name}',
                onTap: () => onCommand(RemoveMediaEntryCommand(id: entry.id)),
              ),
            ),
    );
  }

  String _name(MediaPick pick) {
    final value = pick.source['value']! as String;
    final segments = value.split(RegExp(r'[\\/]'));
    return segments.isEmpty ? value : segments.last;
  }
}
