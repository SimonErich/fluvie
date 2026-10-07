import 'package:fluvie_editor/src/snapping/snap_line.dart';
import 'package:meta/meta.dart' show immutable;

/// A manual guide dragged from a ruler: an orientation and a position as a
/// fraction of the slide (resolution-independent, like every placement).
///
/// Guides persist per slide under the document's `editor` block, so they
/// never touch the render digest.
@immutable
final class ManualGuide {
  /// A guide running [orientation] at [position] (a 0..1 slide fraction).
  const ManualGuide({required this.orientation, required this.position});

  /// Reads the `{'axis': ..., 'pos': ...}` shape [toJson] writes.
  /// Throws an [ArgumentError] for an unknown axis or a missing position.
  factory ManualGuide.fromJson(Map<String, Object?> json) {
    final axis = json['axis'];
    final position = json['pos'];
    final orientation = switch (axis) {
      'vertical' => SnapOrientation.vertical,
      'horizontal' => SnapOrientation.horizontal,
      _ => throw ArgumentError.value(axis, 'axis', 'Expected vertical or horizontal'),
    };
    if (position is! num) {
      throw ArgumentError.value(position, 'pos', 'Expected a number');
    }
    return ManualGuide(orientation: orientation, position: position.toDouble());
  }

  /// Which way the guide runs.
  final SnapOrientation orientation;

  /// Where it sits, as a fraction of the slide's width (vertical guides)
  /// or height (horizontal guides).
  final double position;

  /// The JSON stored in the editor block.
  Map<String, Object?> toJson() => {'axis': orientation.name, 'pos': position};

  /// Reads a stored guide list leniently: anything unreadable (a non-list,
  /// a malformed entry) is dropped, because the editor block is free-form
  /// and may have been hand-edited.
  static List<ManualGuide> listFromJson(Object? json) {
    if (json is! List) return const [];
    return [
      for (final entry in json)
        if (entry is Map<String, Object?> && _readable(entry)) ManualGuide.fromJson(entry),
    ];
  }

  /// Whether [json] carries the axis and position [ManualGuide.fromJson] needs.
  static bool _readable(Map<String, Object?> json) =>
      (json['axis'] == 'vertical' || json['axis'] == 'horizontal') && json['pos'] is num;

  /// The JSON list [listFromJson] reads.
  static List<Object?> listToJson(List<ManualGuide> guides) => [
    for (final guide in guides) guide.toJson(),
  ];

  @override
  bool operator ==(Object other) =>
      other is ManualGuide && other.orientation == orientation && other.position == position;

  @override
  int get hashCode => Object.hash(orientation, position);

  @override
  String toString() => 'ManualGuide(${orientation.name}, $position)';
}
