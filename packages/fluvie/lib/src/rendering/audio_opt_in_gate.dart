import 'package:flutter/widgets.dart' show Widget;
import 'package:fluvie/src/audio/encoding/resolved_audio_track.dart';
import 'package:fluvie/src/composition/runtime/clip_plan_collector.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/core/export.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/rendering/audio_mix_resolution.dart';
import 'package:fluvie/src/rendering/collect_composition_media.dart';
import 'package:fluvie_media/fluvie_media.dart' show MediaTimeline;

/// The one audio-drop policy the on-device and in-browser renderers share.
///
/// Audio is opt-in where the encode runs on the user's device: with [encode]
/// `false`, a [Video] that declares `Audio` yields no mix and warns once
/// through [warnSink] (unless [warn] silences it), naming the platform via
/// [platformLabel] ("on-device", "in-browser"). A non-MP4 [export] cannot
/// carry audio, so it also yields no mix, with its own warning. A non-[Video]
/// composition or one with no declared audio yields `null` silently.
///
/// With the opt-in on and an MP4 target, returns the [ResolvedAudioMix] the
/// renderer stages into its encoder.
///
/// [clipMetadata] rides through to `resolveAudioMix`, which needs it to place a
/// **trimmed** clip's embedded audio; call this after the clip pre-pass so
/// `MediaResolver.clipMetadataFor` can answer.
ResolvedAudioMix? gateOptInAudio({
  required Widget composition,
  required bool encode,
  required bool warn,
  required int fps,
  required int frameCount,
  required void Function(String message) warnSink,
  required String platformLabel,
  Export? export,
  ClipMetadata? Function(MediaSource source)? clipMetadata,
  List<ClipAudioPlan>? mountedClipPlans,
  MediaTimeline? Function(MediaSource source)? clipTimeline,
}) {
  final video = compositionVideo(composition);
  if (video == null) return null;
  final mix = resolveAudioMix(
    video: video,
    fps: fps,
    totalFrames: frameCount,
    clipMetadata: clipMetadata,
    clipTimeline: clipTimeline,
    mountedClipPlans: mountedClipPlans,
  );
  if (mix.isEmpty) return null;
  if (!encode) {
    if (warn) {
      warnSink(
        'This Video declares ${mix.tracks.length} audio track(s), but '
        '$platformLabel audio is off, so the MP4 will be silent. Pass '
        'audio: true to encode it, or warnOnDroppedAudio: false to silence '
        'this warning.',
      );
    }
    return null;
  }
  if (export != null && export.mode != ExportMode.mp4) {
    if (warn) {
      warnSink(
        'Audio is only muxed into MP4 renders; this ${export.mode.name} export '
        'drops the ${mix.tracks.length} declared audio track(s).',
      );
    }
    return null;
  }
  return mix;
}
