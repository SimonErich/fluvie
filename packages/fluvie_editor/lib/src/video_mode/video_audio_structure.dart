import 'package:fluvie/fluvie.dart' show FrameSpan, audioVolumeAt;
import 'package:fluvie_editor/src/audio/audio_track_view.dart';
import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/video_mode/video_lane_bindings.dart';
import 'package:fluvie_editor/src/video_mode/video_lane_model.dart';
import 'package:fluvie_editor/src/video_mode/video_mode_edits.dart';

/// Positional identity of a declared audio track in the current document.
String audioBarId(int? scene, int index) =>
    scene == null ? 'audio:v:$index' : 'audio:s:$scene:$index';

/// The absolute span whose clock owns an audio track.
FrameSpan audioOwnerSpan(VideoLaneModel model, VideoAudioLaneBinding binding) =>
    binding.scene == null
    ? FrameSpan(0, model.totalFrames)
    : model.timebase.sceneSpans[binding.scene!];

/// Why exact structural editing cannot be represented without guessing.
String? audioStructureRefusal(VideoAudioLaneBinding binding, Map<String, Object?> raw) {
  if (binding.isSfx) return 'Convert the sound effect to a trimmed music track before cutting it.';
  if (binding.at == VideoAudioAt.trigger || raw['track'] != null) {
    return 'Place the audio at an explicit time before cutting or rippling its trigger.';
  }
  if (raw['loop'] == true) {
    return 'Turn off looping and set an exact source trim before cutting audio.';
  }
  if (binding.trimFromFrames == null || binding.trimToFrames == null) {
    return 'Set an exact source trim before cutting or rippling audio.';
  }
  return null;
}

/// Splits exact, non-looping music into two adjacent, source-continuous tracks.
/// The tail appends to its owner's list, preserving every existing bar index.
/// [tailId] is accepted for the common razor API; audio identity is positional.
VideoLaneEdit? audioBarRazored(
  VideoLaneModel model,
  String barId,
  int frame, {
  required EditorDocument document,
  String? tailId,
  String? mergeGroup,
}) {
  final binding = model.audioBars[barId];
  if (binding == null) return null;
  if (model.isLocked(barId)) {
    return const VideoLaneEdit.refused('Unlock the lane before cutting audio.');
  }
  if (frame <= binding.span.start || frame >= binding.span.end) {
    return const VideoLaneEdit.refused('Put the playhead inside the audio to razor it.');
  }
  final raw = document.audioTracksJson(scene: binding.scene)[binding.index];
  final refusal = audioStructureRefusal(binding, raw);
  if (refusal != null) return VideoLaneEdit.refused(refusal);
  final head = audioWindowPatch(model, binding, document, binding.span.start, frame);
  final tail = {...raw, ...audioWindowPatch(model, binding, document, frame, binding.span.end)}
    ..removeWhere((_, value) => value == null);
  return VideoLaneEdit.command(
    SequenceCommand(
      [
        SetAudioTrackCommand(index: binding.index, scene: binding.scene, patch: head),
        AddAudioTrackCommand(track: tail, scene: binding.scene),
      ],
      label: 'Razor audio',
      mergeGroup: mergeGroup,
    ),
  );
}

/// A source-preserving crop to an absolute subwindow. Curved automation uses
/// the same resolved samples as export; displaced fades become frame-sampled
/// volume points so neither half restarts its fade or relative envelope.
Map<String, Object?> audioWindowPatch(
  VideoLaneModel model,
  VideoAudioLaneBinding binding,
  EditorDocument document,
  int from,
  int to,
) {
  final owner = audioOwnerSpan(model, binding);
  final offset = from - binding.span.start;
  final length = to - from;
  final sourceFrom = binding.trimFromFrames! + offset;
  final raw = document.audioTracksJson(scene: binding.scene)[binding.index];
  final track = audioTrackViews(document, model.timebase)
      .firstWhere(
        (view) =>
            view.elementId == null && view.scene == binding.scene && view.index == binding.index,
      )
      .resolved;
  final hasFade = track.fadeInSeconds != null || track.fadeOutSeconds != null;
  Map<String, Object?>? automation;
  if (hasFade || track.volumeEnvelope.isNotEmpty) {
    final positions = <int>{0, length};
    if (hasFade) {
      positions.addAll([for (var frame = 1; frame < length; frame++) frame]);
    } else {
      for (final point in track.volumeEnvelope) {
        final frame = (point.seconds * model.fps).round() - offset;
        if (frame > 0 && frame < length) positions.add(frame);
      }
    }
    final ordered = positions.toList()..sort();
    double gain(int frame) {
      final seconds = (offset + frame) / model.fps;
      var value = audioVolumeAt(track.volumeEnvelope, seconds);
      final fadeIn = track.fadeInSeconds;
      if (fadeIn != null) value *= (seconds / fadeIn).clamp(0.0, 1.0);
      final fadeOut = track.fadeOutSeconds;
      if (fadeOut != null) {
        final start = track.fadeOutStartSeconds - track.delayMs / 1000;
        value *= (1 - (seconds - start) / fadeOut).clamp(0.0, 1.0);
      }
      return value;
    }

    automation = {
      'volume': {
        'values': [for (final frame in ordered) gain(frame)],
        'positions': [for (final frame in ordered) '${frame}f'],
      },
    };
  }
  return {
    'at': {'kind': 'at', 'time': '${from - owner.start}f'},
    'trim': {'from': '${sourceFrom}f', 'to': '${sourceFrom + length}f'},
    if (raw.containsKey('automation') || automation != null) 'automation': automation,
    if (raw.containsKey('fadeIn')) 'fadeIn': null,
    if (raw.containsKey('fadeOut')) 'fadeOut': null,
  };
}

/// Moves an exact track without reinterpreting relative automation positions.
SetAudioTrackCommand audioShiftCommand(
  VideoLaneModel model,
  VideoAudioLaneBinding binding,
  EditorDocument document,
  int delta,
) {
  final patch = audioWindowPatch(model, binding, document, binding.span.start, binding.span.end);
  patch['at'] = {
    'kind': 'at',
    'time': '${binding.span.start - audioOwnerSpan(model, binding).start + delta}f',
  };
  return SetAudioTrackCommand(index: binding.index, scene: binding.scene, patch: patch);
}
