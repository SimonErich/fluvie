// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'embedded_video_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EmbeddedVideoConfig _$EmbeddedVideoConfigFromJson(Map<String, dynamic> json) =>
    EmbeddedVideoConfig(
      videoPath: json['videoPath'] as String,
      startFrame: (json['startFrame'] as num).toInt(),
      durationInFrames: (json['durationInFrames'] as num).toInt(),
      trimStartSeconds: (json['trimStartSeconds'] as num).toDouble(),
      width: (json['width'] as num).toInt(),
      height: (json['height'] as num).toInt(),
      positionX: (json['positionX'] as num?)?.toDouble() ?? 0,
      positionY: (json['positionY'] as num?)?.toDouble() ?? 0,
      includeAudio: json['includeAudio'] as bool? ?? true,
      audioVolume: (json['audioVolume'] as num?)?.toDouble() ?? 1.0,
      audioFadeInFrames: (json['audioFadeInFrames'] as num?)?.toInt() ?? 0,
      audioFadeOutFrames: (json['audioFadeOutFrames'] as num?)?.toInt() ?? 0,
      id: json['id'] as String,
    );

Map<String, dynamic> _$EmbeddedVideoConfigToJson(
  EmbeddedVideoConfig instance,
) => <String, dynamic>{
  'videoPath': instance.videoPath,
  'startFrame': instance.startFrame,
  'durationInFrames': instance.durationInFrames,
  'trimStartSeconds': instance.trimStartSeconds,
  'width': instance.width,
  'height': instance.height,
  'positionX': instance.positionX,
  'positionY': instance.positionY,
  'includeAudio': instance.includeAudio,
  'audioVolume': instance.audioVolume,
  'audioFadeInFrames': instance.audioFadeInFrames,
  'audioFadeOutFrames': instance.audioFadeOutFrames,
  'id': instance.id,
};
