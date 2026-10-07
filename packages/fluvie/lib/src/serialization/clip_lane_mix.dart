import 'package:fluvie/src/serialization/anchor_table.dart';
import 'package:fluvie/src/serialization/element_spec.dart';

/// Applies authored lane controls to embedded clip audio at build time.
/// Returns the original spec for unchanged lanes, preserving authored data.
ElementSpec applyClipLaneMix(
  ElementSpec element,
  AnchorTable anchors, {
  required Set<String> mutedLaneIds,
  required Map<String, double> laneGains,
}) {
  if (mutedLaneIds.isEmpty && laneGains.values.every((gain) => gain == 1)) return element;
  Map<String, Object?> visit(Map<String, Object?> raw) {
    final result = Map<String, Object?>.of(raw);
    if (raw['type'] == 'Clip') {
      final lane = raw['lane'];
      final gain = mutedLaneIds.contains(lane) ? 0.0 : laneGains[lane] ?? 1.0;
      if (gain != 1) result['volume'] = ((raw['volume'] as num?) ?? 1) * gain;
    }
    if (raw['children'] case final List<Object?> children) {
      result['children'] = [for (final child in children) visit(child! as Map<String, Object?>)];
    }
    if (raw['child'] case final Map<String, Object?> child) result['child'] = visit(child);
    return result;
  }

  return ElementSpec.fromJson(visit(element.toJson()), anchors);
}
