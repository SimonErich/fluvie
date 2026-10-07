import 'package:flutter/widgets.dart';
import 'package:fluvie_editor/src/media/media_bin.dart';
import 'package:fluvie_editor/src/media/media_store_entry.dart';
import 'package:fluvie_editor/src/media/source_monitor.dart';
import 'package:obers_ui/obers_ui.dart';

part 'media_bin_panel_state.dart';
part 'media_bin_row.dart';
part 'media_bin_folder_chip.dart';

/// The bin: everything imported into the deck, filed, searchable, and
/// previewable before it is placed.
///
/// It holds no copy of the store. The listing is recomputed from [entries] and
/// the live query on every build, so a panel can never show media the document
/// no longer has.
final class MediaBinPanel extends StatefulWidget {
  /// Lists [entries], reporting an edited entry to [onEntryChanged] and a
  /// placement to [onPlace].
  const MediaBinPanel({
    required this.entries,
    required this.onEntryChanged,
    this.onPlace,
    this.onImport,
    this.previewBuilder,
    super.key,
  });

  /// The deck's media, in import order.
  final List<MediaStoreEntry> entries;

  /// Receives an entry whose folder or marks changed.
  final ValueChanged<MediaStoreEntry> onEntryChanged;

  /// Places a marked range, or null where the host has nowhere to place it.
  final ValueChanged<SourceMonitorPlacement>? onPlace;

  /// Imports a new file, or null where the host offers no importer.
  final VoidCallback? onImport;

  /// Decoded source preview driven by the monitor playhead.
  final Widget Function(BuildContext context, MediaStoreEntry entry, int frame)? previewBuilder;

  @override
  State<MediaBinPanel> createState() => _MediaBinPanelState();
}
