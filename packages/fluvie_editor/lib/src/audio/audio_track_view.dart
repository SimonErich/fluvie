import 'dart:math' as math;

import 'package:flutter/widgets.dart' show Widget;
import 'package:fluvie/fluvie.dart'
    show AbsoluteTrigger, AudioTrackSpec, Clip, FrameSpan, SpecElementId, decodeTime;
import 'package:fluvie/rendering.dart'
    show
        AudioTimeMap,
        ClipMetadata,
        MotionTarget,
        ResolvedAudioTrack,
        TimeScopeData,
        clipAudioSourceFor,
        declaredChildren,
        elementScopeFor,
        integrateClipSpeedRamp,
        resolveAudioTrack,
        resolveClipAudioTrimSeconds;
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/video_mode/video_timebase.dart';

part 'audio_clip_view.dart';

/// The document address, audible window and encoder mix facts of one track.
final class AudioTrackView {
  /// Creates a resolved view, preserving document declaration order.
  const AudioTrackView({
    required this.scene,
    required this.index,
    required this.spec,
    required this.span,
    required this.resolved,
    this.elementId,
    this.unavailableReason,
  });

  /// Owning scene, or null for the video-level track list.
  final int? scene;

  /// Index in the owner's audio list.
  final int index;

  /// Authored audio spec.
  final AudioTrackSpec spec;

  /// Absolute audible window.
  final FrameSpan span;

  /// Same values the export mixer consumes.
  final ResolvedAudioTrack resolved;

  /// Clip element identity, or null for a declared audio track.
  final String? elementId;

  /// Why a clip cannot be auditioned until its source metadata is loaded.
  final String? unavailableReason;

  /// Stable address within the current document.
  String get id => elementId == null ? '${scene ?? 'video'}:$index' : 'clip:$elementId';

  /// Source value used by the cache.
  String get sourceKey => (spec.toJson()['source']! as Map)['value']! as String;

  /// Human-readable file label.
  String get label => sourceKey.split('/').last;
}

/// Resolves declared video and scene tracks for meters, automation and ducking.
List<AudioTrackView> audioTrackViews(
  EditorDocument document,
  VideoTimebase timebase, {
  Map<String, ClipMetadata> clipMetadata = const {},
}) {
  final result = <AudioTrackView>[];
  final owners = <int?>[null, for (var i = 0; i < document.sceneCount; i++) i];
  for (final scene in owners) {
    final specs = scene == null ? document.spec.audio : document.spec.scenes[scene].audio;
    final owner = scene == null ? FrameSpan(0, timebase.totalFrames) : timebase.sceneSpans[scene];
    for (var i = 0; i < specs.length; i++) {
      final spec = specs[i];
      final scope = OwnerFrameScope(timebase.fps, owner);
      final offset = spec.at is AbsoluteTrigger
          ? (spec.at! as AbsoluteTrigger).time.resolveFrames(scope)
          : 0;
      var duration = owner.durationFrames - offset;
      if (!spec.loop && spec.trim != null) {
        final trim = spec.trim!.resolveFrames(scope);
        if (trim.end - trim.start < duration) duration = trim.end - trim.start;
      }
      if (!spec.loop && spec.trim == null) {
        final source = (spec.toJson()['source']! as Map)['value'];
        for (final entry in document.mediaEntries) {
          if (entry.source['value'] == source && entry.duration != null) {
            final mediaFrames = decodeTime(entry.duration).resolveFrames(scope);
            if (mediaFrames < duration) duration = mediaFrames;
            break;
          }
        }
      }
      final gain = document.spec.mutedLaneIds.contains(spec.lane)
          ? 0.0
          : document.spec.laneGains[spec.lane] ?? 1.0;
      final track = spec.build(laneGain: gain).inWindow(owner.start, owner.durationFrames);
      result.add(
        AudioTrackView(
          scene: scene,
          index: i,
          spec: spec,
          span: FrameSpan(owner.start + offset, owner.start + offset + duration),
          resolved: resolveAudioTrack(
            track,
            fps: timebase.fps,
            scope: TimeScopeData(
              fps: timebase.fps,
              startFrame: 0,
              durationFrames: timebase.totalFrames,
            ),
          ),
        ),
      );
    }
  }
  result.addAll(_clipTrackViews(document, timebase, clipMetadata));
  return result;
}
