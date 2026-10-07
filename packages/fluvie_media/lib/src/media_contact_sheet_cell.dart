/// One picture in a contact sheet, with its actual source display time.
final class MediaContactSheetCell {
  /// Creates a positioned source-picture record.
  const MediaContactSheetCell({
    required this.frameIndex,
    required this.timeSeconds,
    required this.requestedTimeSeconds,
    required this.column,
    required this.row,
  });

  /// Original decoded source ordinal.
  final int frameIndex;

  /// Source presentation time of the visible picture, in seconds.
  final double timeSeconds;

  /// Time requested by the caller, before selection of its held picture.
  final double requestedTimeSeconds;

  /// Zero-based column and row in the image.
  final int column;

  /// Zero-based image row.
  final int row;

  /// Facts to retain beside the image for an agent or human reviewer.
  Map<String, Object?> toJson() => {
    'frameIndex': frameIndex,
    'timeSeconds': timeSeconds,
    'requestedTimeSeconds': requestedTimeSeconds,
    'column': column,
    'row': row,
  };
}
