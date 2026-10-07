import 'package:fluvie_media/src/media_contact_sheet_cell.dart';

/// A generated PNG and the source facts for each of its pictures.
final class MediaContactSheet {
  /// Creates a receipt with an immutable cell list.
  MediaContactSheet({
    required this.filePath,
    required this.width,
    required this.height,
    required Iterable<MediaContactSheetCell> cells,
  }) : cells = List.unmodifiable(cells);

  /// Absolute location of the PNG.
  final String filePath;

  /// Contact-sheet pixel width.
  final int width;

  /// Contact-sheet pixel height.
  final int height;

  /// Ordered picture/timestamp records; no semantic descriptions are inferred.
  final List<MediaContactSheetCell> cells;

  /// A versioned receipt suitable for a cached evidence manifest.
  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'filePath': filePath,
    'width': width,
    'height': height,
    'cells': cells.map((cell) => cell.toJson()).toList(),
  };
}
