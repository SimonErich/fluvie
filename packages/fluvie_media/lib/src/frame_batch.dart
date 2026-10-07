/// Maximum decoded bytes retained by one extraction batch (128 MiB).
const int defaultFrameBatchBytes = 128 * 1024 * 1024;

/// Sorts and deduplicates requested indices, then bounds raw pixel memory.
List<List<int>> frameBatches(
  Iterable<int> indices, {
  required int width,
  required int height,
  int maxBytes = defaultFrameBatchBytes,
}) {
  if (width <= 0 || height <= 0 || maxBytes < width * height * 4) {
    throw ArgumentError('Frame dimensions must be positive and one frame must fit in maxBytes.');
  }
  final sorted = indices.toSet().toList()..sort();
  if (sorted.any((index) => index < 0)) throw ArgumentError('Frame indices must not be negative.');
  // Also bound filter expression length for Windows process argument limits.
  final capacity = (maxBytes ~/ (width * height * 4)).clamp(1, 512);
  return [
    for (var start = 0; start < sorted.length; start += capacity)
      sorted.sublist(start, (start + capacity).clamp(0, sorted.length)),
  ];
}

/// Exact frame-selection filter. No output-rate resampling or duplication.
String frameSelectFilter(List<int> indices, {required int width, required int height}) =>
    'select=${indices.map((index) => 'eq(n\\,$index)').join('+')},scale=$width:$height';
