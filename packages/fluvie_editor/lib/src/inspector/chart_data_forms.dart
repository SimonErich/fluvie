/// The pure vocabulary behind the chart Data section's form switching:
/// which of the spec's three `Chart` data shapes an element holds, which
/// shapes its variant can legally hold, and the honest conversions between
/// them. Anything lossy refuses with a note instead of converting.
library;

/// The three data shapes a spec `Chart` can hold.
enum ChartDataForm {
  /// The category-to-value `data` map (every variant reads it).
  map,

  /// The `series` list (line and area; scatter with exactly one).
  series,

  /// The `points` list (scatter only).
  points,
}

/// The data form [element] holds right now. An element with none of the
/// three keys reads as [ChartDataForm.map] (the empty default the grid
/// seeds).
ChartDataForm chartDataFormOf(Map<String, Object?> element) {
  if (element['series'] is List) return ChartDataForm.series;
  if (element['points'] is List) return ChartDataForm.points;
  return ChartDataForm.map;
}

/// The data forms [variant] can legally hold, mirroring the codec: bar,
/// pie, and donut read only the map; line and area add series; scatter
/// reads all three. An unknown or missing variant stays map-only.
List<ChartDataForm> chartFormsFor(String? variant) => switch (variant) {
  'line' || 'area' => const [ChartDataForm.map, ChartDataForm.series],
  'scatter' => ChartDataForm.values,
  _ => const [ChartDataForm.map],
};

/// The outcome of a form conversion: a patch to apply, or a refusal.
sealed class ChartFormChange {
  const ChartFormChange();
}

/// The conversion is honest: [patch] rewrites the element's data shape.
final class ChartFormPatch extends ChartFormChange {
  /// Wraps the element patch.
  const ChartFormPatch(this.patch);

  /// The content patch (null values remove their keys).
  final Map<String, Object?> patch;
}

/// The conversion would lose data: [note] says what, for the UI to show.
final class ChartFormRefusal extends ChartFormChange {
  /// Wraps the refusal note.
  const ChartFormRefusal(this.note);

  /// Why the conversion refused, in one visible sentence.
  final String note;
}

/// Converts [element]'s data to form [to], honestly or not at all.
///
/// The defined conversions:
///
/// - map to series: the map becomes `Series 1` — lossless.
/// - map to points: index `i` becomes `x`, the key becomes `label` —
///   lossless, and the inverse below round-trips it.
/// - series to map: only a SINGLE series holding a `data` map converts;
///   its `name` and `color` are presentation of the wrapper and drop (the
///   defined reading of "`series[0]` becomes the map"). Multiple series and
///   points-holding series refuse.
/// - points to map: only when every `x` equals its index (real x data
///   would be lost) and the labels (minted `P2`-style where absent) do not
///   collide.
/// - series and points never convert into each other directly — go
///   through the map form, so every step stays inspectable.
///
/// Converting to the current form throws an [ArgumentError] (the select
/// never offers it).
ChartFormChange convertChartForm(Map<String, Object?> element, ChartDataForm to) {
  final from = chartDataFormOf(element);
  if (from == to) {
    throw ArgumentError.value(to, 'to', 'Already the current form');
  }
  return switch ((from, to)) {
    (ChartDataForm.map, ChartDataForm.series) => ChartFormPatch({
      'data': null,
      'series': [
        {'name': 'Series 1', 'data': _mapOf(element)},
      ],
    }),
    (ChartDataForm.map, ChartDataForm.points) => ChartFormPatch({
      'data': null,
      'points': [
        for (final (index, entry) in _mapOf(element).entries.indexed)
          {'x': index, 'y': entry.value, 'label': entry.key},
      ],
    }),
    (ChartDataForm.series, ChartDataForm.map) => _seriesToMap(element),
    (ChartDataForm.points, ChartDataForm.map) => _pointsToMap(element),
    _ => const ChartFormRefusal('Convert through the map form first'),
  };
}

Map<String, Object?> _mapOf(Map<String, Object?> element) => element['data'] is Map<String, Object?>
    ? element['data']! as Map<String, Object?>
    : const <String, Object?>{};

ChartFormChange _seriesToMap(Map<String, Object?> element) {
  final series = (element['series']! as List).cast<Map<String, Object?>>();
  if (series.length != 1) {
    return const ChartFormRefusal('Only a single series converts to a map');
  }
  final data = series.single['data'];
  if (data is! Map<String, Object?>) {
    return const ChartFormRefusal('A points series has no map form');
  }
  return ChartFormPatch({
    'series': null,
    'data': {...data},
  });
}

ChartFormChange _pointsToMap(Map<String, Object?> element) {
  final points = (element['points']! as List).cast<Map<String, Object?>>();
  final data = <String, Object?>{};
  for (final (index, point) in points.indexed) {
    if (point['x'] != index) {
      return const ChartFormRefusal(
        'The x values would be lost; only index-aligned points convert',
      );
    }
    final label = point['label'] is String ? point['label']! as String : 'P${index + 1}';
    if (data.containsKey(label)) {
      return const ChartFormRefusal('Point labels collide; rename them first');
    }
    data[label] = point['y'];
  }
  return ChartFormPatch({'points': null, 'data': data});
}
