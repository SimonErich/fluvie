import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:fluvie_editor/src/media/media_store_entry.dart';
import 'package:fluvie_editor/src/widgets/numeric_unit.dart';
import 'package:obers_ui/obers_ui.dart';

part 'source_monitor_state.dart';
part 'source_monitor_status.dart';

/// What the monitor asks the host to do with a marked asset.
typedef SourceMonitorPlacement = ({MediaStoreEntry entry, int start, int end});

/// The bin's preview: scrub an asset, mark its in and out, and place the range.
///
/// The marks belong to the **asset**, not to a placement, so marking once and
/// placing three times gives three clips of the same range. Placing is what
/// writes the range into an element's own `trim`; the monitor only decides
/// which range that is.
///
/// It renders no frames itself. Decoding a preview needs a resolver the editor
/// only has after a render pre-pass, so the monitor draws the position and the
/// marks and leaves the picture to whatever the host puts in [preview] — which
/// can also be supplied as a frame-aware [previewBuilder].
final class SourceMonitor extends StatefulWidget {
  /// Shows [entry] with its current marks.
  const SourceMonitor({
    required this.entry,
    required this.onMarked,
    this.onPlace,
    this.preview,
    this.previewBuilder,
    super.key,
  });

  /// The asset being previewed.
  final MediaStoreEntry entry;

  /// Receives the asset with its marks changed.
  final ValueChanged<MediaStoreEntry> onMarked;

  /// Places the marked range on the timeline, or null where the host has
  /// nowhere to place it yet.
  final ValueChanged<SourceMonitorPlacement>? onPlace;

  /// The picture, where the host can draw one.
  final Widget? preview;

  /// Builds a decoded picture or audio waveform at the source playhead.
  final Widget Function(BuildContext context, MediaStoreEntry entry, int frame)? previewBuilder;

  @override
  State<SourceMonitor> createState() => _SourceMonitorState();
}
