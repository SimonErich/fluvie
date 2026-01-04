// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AudioTrackConfig _$AudioTrackConfigFromJson(Map<String, dynamic> json) =>
    AudioTrackConfig(
      source: AudioSourceConfig.fromJson(
        json['source'] as Map<String, dynamic>,
      ),
      startFrame: (json['startFrame'] as num).toInt(),
      durationInFrames: (json['durationInFrames'] as num).toInt(),
      trimStartFrame: (json['trimStartFrame'] as num?)?.toInt() ?? 0,
      trimEndFrame: (json['trimEndFrame'] as num?)?.toInt(),
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
      fadeInFrames: (json['fadeInFrames'] as num?)?.toInt() ?? 0,
      fadeOutFrames: (json['fadeOutFrames'] as num?)?.toInt() ?? 0,
      loop: json['loop'] as bool? ?? false,
      sync: json['sync'] == null
          ? null
          : AudioSyncConfig.fromJson(json['sync'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$AudioTrackConfigToJson(AudioTrackConfig instance) =>
    <String, dynamic>{
      'source': instance.source.toJson(),
      'startFrame': instance.startFrame,
      'durationInFrames': instance.durationInFrames,
      'trimStartFrame': instance.trimStartFrame,
      'trimEndFrame': instance.trimEndFrame,
      'volume': instance.volume,
      'fadeInFrames': instance.fadeInFrames,
      'fadeOutFrames': instance.fadeOutFrames,
      'loop': instance.loop,
      'sync': instance.sync?.toJson(),
    };

AudioSourceConfig _$AudioSourceConfigFromJson(Map<String, dynamic> json) =>
    AudioSourceConfig(
      type: $enumDecode(_$AudioSourceTypeEnumMap, json['type']),
      uri: json['uri'] as String,
    );

Map<String, dynamic> _$AudioSourceConfigToJson(AudioSourceConfig instance) =>
    <String, dynamic>{
      'type': _$AudioSourceTypeEnumMap[instance.type]!,
      'uri': instance.uri,
    };

const _$AudioSourceTypeEnumMap = {
  AudioSourceType.asset: 'asset',
  AudioSourceType.file: 'file',
  AudioSourceType.url: 'url',
};

AudioSyncConfig _$AudioSyncConfigFromJson(Map<String, dynamic> json) =>
    AudioSyncConfig(
      syncStartWithAnchor: json['syncStartWithAnchor'] as String?,
      syncEndWithAnchor: json['syncEndWithAnchor'] as String?,
      startOffset: (json['startOffset'] as num?)?.toInt() ?? 0,
      endOffset: (json['endOffset'] as num?)?.toInt() ?? 0,
      behavior: $enumDecodeNullable(_$SyncBehaviorEnumMap, json['behavior']) ??
          SyncBehavior.stopWhenEnds,
    );

Map<String, dynamic> _$AudioSyncConfigToJson(AudioSyncConfig instance) =>
    <String, dynamic>{
      'syncStartWithAnchor': instance.syncStartWithAnchor,
      'syncEndWithAnchor': instance.syncEndWithAnchor,
      'startOffset': instance.startOffset,
      'endOffset': instance.endOffset,
      'behavior': _$SyncBehaviorEnumMap[instance.behavior]!,
    };

const _$SyncBehaviorEnumMap = {
  SyncBehavior.stopWhenEnds: 'stop_when_ends',
  SyncBehavior.loopToMatch: 'loop_to_match',
};
