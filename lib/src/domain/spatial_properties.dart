import 'package:json_annotation/json_annotation.dart';

part 'spatial_properties.g.dart';

/// Spatial transformation properties for positioning and scaling content.
///
/// Used by [SequenceConfig] to define how content is positioned, scaled,
/// and rotated within the video frame.
///
/// Example:
/// ```dart
/// SpatialProperties(
///   x: 100,
///   y: 50,
///   width: 400,
///   height: 300,
///   rotation: 45,
///   opacity: 0.8,
/// )
/// ```
@JsonSerializable()
class SpatialProperties {
  /// Horizontal position in pixels from the left edge.
  final double? x;

  /// Vertical position in pixels from the top edge.
  final double? y;

  /// Width in pixels. If null, uses natural width.
  final double? width;

  /// Height in pixels. If null, uses natural height.
  final double? height;

  /// Rotation angle in degrees (clockwise).
  final double? rotation;

  /// Horizontal scale factor (1.0 = 100%).
  final double? scaleX;

  /// Vertical scale factor (1.0 = 100%).
  final double? scaleY;

  /// Opacity from 0.0 (transparent) to 1.0 (opaque).
  final double? opacity;

  /// Anchor point X (0.0 = left, 0.5 = center, 1.0 = right).
  final double? anchorX;

  /// Anchor point Y (0.0 = top, 0.5 = center, 1.0 = bottom).
  final double? anchorY;

  /// Creates spatial properties.
  const SpatialProperties({
    this.x,
    this.y,
    this.width,
    this.height,
    this.rotation,
    this.scaleX,
    this.scaleY,
    this.opacity,
    this.anchorX,
    this.anchorY,
  });

  /// Creates spatial properties with all values set to their defaults.
  const SpatialProperties.identity()
      : x = 0,
        y = 0,
        width = null,
        height = null,
        rotation = 0,
        scaleX = 1.0,
        scaleY = 1.0,
        opacity = 1.0,
        anchorX = 0.5,
        anchorY = 0.5;

  /// Creates spatial properties centered in the frame.
  const SpatialProperties.centered({
    this.width,
    this.height,
    this.rotation,
    this.scaleX,
    this.scaleY,
    this.opacity,
  })  : x = null,
        y = null,
        anchorX = 0.5,
        anchorY = 0.5;

  /// Creates a copy with the given values replaced.
  SpatialProperties copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    double? scaleX,
    double? scaleY,
    double? opacity,
    double? anchorX,
    double? anchorY,
  }) {
    return SpatialProperties(
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      rotation: rotation ?? this.rotation,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      opacity: opacity ?? this.opacity,
      anchorX: anchorX ?? this.anchorX,
      anchorY: anchorY ?? this.anchorY,
    );
  }

  /// Converts to a Map for backward compatibility.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      if (x != null) 'x': x,
      if (y != null) 'y': y,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (rotation != null) 'rotation': rotation,
      if (scaleX != null) 'scaleX': scaleX,
      if (scaleY != null) 'scaleY': scaleY,
      if (opacity != null) 'opacity': opacity,
      if (anchorX != null) 'anchorX': anchorX,
      if (anchorY != null) 'anchorY': anchorY,
    };
  }

  /// Creates from a Map for backward compatibility.
  factory SpatialProperties.fromMap(Map<String, dynamic> map) {
    return SpatialProperties(
      x: (map['x'] as num?)?.toDouble(),
      y: (map['y'] as num?)?.toDouble(),
      width: (map['width'] as num?)?.toDouble(),
      height: (map['height'] as num?)?.toDouble(),
      rotation: (map['rotation'] as num?)?.toDouble(),
      scaleX: (map['scaleX'] as num?)?.toDouble(),
      scaleY: (map['scaleY'] as num?)?.toDouble(),
      opacity: (map['opacity'] as num?)?.toDouble(),
      anchorX: (map['anchorX'] as num?)?.toDouble(),
      anchorY: (map['anchorY'] as num?)?.toDouble(),
    );
  }

  factory SpatialProperties.fromJson(Map<String, dynamic> json) =>
      _$SpatialPropertiesFromJson(json);
  Map<String, dynamic> toJson() => _$SpatialPropertiesToJson(this);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SpatialProperties &&
        other.x == x &&
        other.y == y &&
        other.width == width &&
        other.height == height &&
        other.rotation == rotation &&
        other.scaleX == scaleX &&
        other.scaleY == scaleY &&
        other.opacity == opacity &&
        other.anchorX == anchorX &&
        other.anchorY == anchorY;
  }

  @override
  int get hashCode {
    return Object.hash(
      x,
      y,
      width,
      height,
      rotation,
      scaleX,
      scaleY,
      opacity,
      anchorX,
      anchorY,
    );
  }
}
