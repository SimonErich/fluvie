// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'render_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RenderConfig _$RenderConfigFromJson(Map<String, dynamic> json) => RenderConfig(
  timeline: TimelineConfig.fromJson(json['timeline'] as Map<String, dynamic>),
  sequences: (json['sequences'] as List<dynamic>)
      .map((e) => SequenceConfig.fromJson(e as Map<String, dynamic>))
      .toList(),
  audioTracks:
      (json['audioTracks'] as List<dynamic>?)
          ?.map((e) => AudioTrackConfig.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  embeddedVideos:
      (json['embeddedVideos'] as List<dynamic>?)
          ?.map((e) => EmbeddedVideoConfig.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  encoding: json['encoding'] == null
      ? null
      : EncodingConfig.fromJson(json['encoding'] as Map<String, dynamic>),
);

Map<String, dynamic> _$RenderConfigToJson(RenderConfig instance) =>
    <String, dynamic>{
      'timeline': instance.timeline.toJson(),
      'sequences': instance.sequences.map((e) => e.toJson()).toList(),
      'audioTracks': instance.audioTracks.map((e) => e.toJson()).toList(),
      'embeddedVideos': instance.embeddedVideos.map((e) => e.toJson()).toList(),
      'encoding': instance.encoding?.toJson(),
    };

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

const _$SequenceTypeEnumMap = {
  SequenceType.base: 'base',
  SequenceType.video: 'video',
  SequenceType.text: 'text',
  SequenceType.composite: 'composite',
};

SequenceConfig _$SequenceConfigFromJson(Map<String, dynamic> json) =>
    SequenceConfig(
      type:
          $enumDecodeNullable(_$SequenceTypeEnumMap, json['type']) ??
          SequenceType.base,
      startFrame: (json['startFrame'] as num).toInt(),
      durationInFrames: (json['durationInFrames'] as num).toInt(),
      spatialProps: json['spatialProps'] == null
          ? null
          : SpatialProperties.fromJson(
              json['spatialProps'] as Map<String, dynamic>,
            ),
      children: (json['children'] as List<dynamic>?)
          ?.map((e) => SequenceConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
      assetPath: json['assetPath'] as String?,
      trimStartFrame: (json['trimStartFrame'] as num?)?.toInt(),
      trimDurationInFrames: (json['trimDurationInFrames'] as num?)?.toInt(),
      text: json['text'] as String?,
    );

Map<String, dynamic> _$SequenceConfigToJson(SequenceConfig instance) =>
    <String, dynamic>{
      'type': _$SequenceTypeEnumMap[instance.type]!,
      'startFrame': instance.startFrame,
      'durationInFrames': instance.durationInFrames,
      'spatialProps': instance.spatialProps?.toJson(),
      'children': instance.children?.map((e) => e.toJson()).toList(),
      'assetPath': instance.assetPath,
      'trimStartFrame': instance.trimStartFrame,
      'trimDurationInFrames': instance.trimDurationInFrames,
      'text': instance.text,
    };

const _$FrameFormatEnumMap = {
  FrameFormat.rawRgba: 'raw_rgba',
  FrameFormat.png: 'png',
};

const _$RenderQualityEnumMap = {
  RenderQuality.low: 'low',
  RenderQuality.medium: 'medium',
  RenderQuality.high: 'high',
  RenderQuality.lossless: 'lossless',
};

EncodingConfig _$EncodingConfigFromJson(Map<String, dynamic> json) =>
    EncodingConfig(
      quality:
          $enumDecodeNullable(_$RenderQualityEnumMap, json['quality']) ??
          RenderQuality.medium,
      crfOverride: (json['crfOverride'] as num?)?.toInt(),
      presetOverride: json['presetOverride'] as String?,
      frameFormat:
          $enumDecodeNullable(_$FrameFormatEnumMap, json['frameFormat']) ??
          FrameFormat.rawRgba,
    );

Map<String, dynamic> _$EncodingConfigToJson(EncodingConfig instance) =>
    <String, dynamic>{
      'quality': _$RenderQualityEnumMap[instance.quality]!,
      'crfOverride': instance.crfOverride,
      'presetOverride': instance.presetOverride,
      'frameFormat': _$FrameFormatEnumMap[instance.frameFormat]!,
    };
