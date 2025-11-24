// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'render_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RenderConfig _$RenderConfigFromJson(Map<String, dynamic> json) => RenderConfig(
  timeline: TimelineConfig.fromJson(json['timeline'] as Map<String, dynamic>),
  clips: (json['clips'] as List<dynamic>)
      .map((e) => ClipConfig.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$RenderConfigToJson(RenderConfig instance) =>
    <String, dynamic>{'timeline': instance.timeline, 'clips': instance.clips};

TimelineConfig _$TimelineConfigFromJson(Map<String, dynamic> json) =>
    TimelineConfig(
      fps: (json['fps'] as num).toInt(),
      durationInFrames: (json['durationInFrames'] as num).toInt(),
      width: (json['width'] as num).toInt(),
      height: (json['height'] as num).toInt(),
    );

Map<String, dynamic> _$TimelineConfigToJson(TimelineConfig instance) =>
    <String, dynamic>{
      'fps': instance.fps,
      'durationInFrames': instance.durationInFrames,
      'width': instance.width,
      'height': instance.height,
    };

ClipConfig _$ClipConfigFromJson(Map<String, dynamic> json) => ClipConfig(
  startFrame: (json['startFrame'] as num).toInt(),
  durationInFrames: (json['durationInFrames'] as num).toInt(),
  spatialProps: json['spatialProps'] as Map<String, dynamic>? ?? const {},
  child: json['child'] == null
      ? null
      : ClipConfig.fromJson(json['child'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ClipConfigToJson(ClipConfig instance) =>
    <String, dynamic>{
      'startFrame': instance.startFrame,
      'durationInFrames': instance.durationInFrames,
      'spatialProps': instance.spatialProps,
      'child': instance.child,
    };
