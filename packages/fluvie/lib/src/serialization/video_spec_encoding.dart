part of 'video_spec.dart';

// Canonical document encoding; declaration and optional-key order remain unchanged.
Map<String, Object?> _encodeVideoSpec(VideoSpec spec) => {
  'fluvieSpec': VideoSpec.schemaVersion,
  'size': encodeVideoSize(spec.size),
  'fps': spec.fps,
  if (spec.poster != null) 'poster': encodeTime(spec.poster!),
  if (spec.export != null) 'export': encodeExport(spec.export!),
  if (spec.motionDefaults != null) 'motionDefaults': encodeDefaults(spec.motionDefaults!),
  if (spec.transition != null) 'transition': encodeTransition(spec.transition!),
  if (spec.theme != null) 'theme': spec.theme!.toJson(),
  if (spec.masters.isNotEmpty)
    'masters': {for (final entry in spec.masters.entries) entry.key: entry.value.toJson()},
  if (spec.audio.isNotEmpty) 'audio': [for (final track in spec.audio) track.toJson()],
  if (spec.lanes.isNotEmpty) 'lanes': [for (final lane in spec.lanes) lane.toJson()],
  if (spec.overlays.isNotEmpty) 'overlays': [for (final overlay in spec.overlays) overlay.toJson()],
  'scenes': [for (final scene in spec.scenes) scene.toJson()],
  if (spec.editorData != null) 'editor': spec.editorData,
};
