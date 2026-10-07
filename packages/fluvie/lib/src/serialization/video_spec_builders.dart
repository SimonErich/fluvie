part of 'video_spec.dart';

// Composition construction stays inside the document theme resolution scope.
Video _buildVideoSpec(VideoSpec spec) => ThemeSpec.resolve(
  spec.theme,
  () => Video(
    size: spec.size,
    fps: spec.fps,
    poster: spec.poster,
    export: spec.export,
    motionDefaults: spec.effectiveMotionDefaults,
    transition: spec.transition,
    audio: spec.buildAudio(),
    overlays: spec.buildOverlays(),
    scenes: [
      for (final scene in spec.scenes)
        resolveSceneMaster(
          scene,
          spec.masters,
        ).build(
          spec.anchors,
          mutedLaneIds: spec.mutedLaneIds,
          laneGains: spec.laneGains,
          fps: spec.fps,
        ),
    ],
  ),
);
