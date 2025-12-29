// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'spatial_properties.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SpatialProperties _$SpatialPropertiesFromJson(Map<String, dynamic> json) =>
    SpatialProperties(
      x: (json['x'] as num?)?.toDouble(),
      y: (json['y'] as num?)?.toDouble(),
      width: (json['width'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
      rotation: (json['rotation'] as num?)?.toDouble(),
      scaleX: (json['scaleX'] as num?)?.toDouble(),
      scaleY: (json['scaleY'] as num?)?.toDouble(),
      opacity: (json['opacity'] as num?)?.toDouble(),
      anchorX: (json['anchorX'] as num?)?.toDouble(),
      anchorY: (json['anchorY'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$SpatialPropertiesToJson(SpatialProperties instance) =>
    <String, dynamic>{
      'x': instance.x,
      'y': instance.y,
      'width': instance.width,
      'height': instance.height,
      'rotation': instance.rotation,
      'scaleX': instance.scaleX,
      'scaleY': instance.scaleY,
      'opacity': instance.opacity,
      'anchorX': instance.anchorX,
      'anchorY': instance.anchorY,
    };
