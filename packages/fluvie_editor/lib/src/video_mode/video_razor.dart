import 'package:fluvie/fluvie.dart' show FrameSpan, KeyframedNumber, Time, introspectTimeline;
import 'package:fluvie/rendering.dart' show integrateClipSpeedRamp;
import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/transitions/transition_structure_edits.dart';
import 'package:fluvie_editor/src/video_mode/clip_audio_slice.dart';
import 'package:fluvie_editor/src/video_mode/clip_trim_seconds.dart';
import 'package:fluvie_editor/src/video_mode/video_audio_structure.dart';
import 'package:fluvie_editor/src/video_mode/video_element_owner.dart';
import 'package:fluvie_editor/src/video_mode/video_lane_bindings.dart';
import 'package:fluvie_editor/src/video_mode/video_lane_model.dart';
import 'package:fluvie_editor/src/video_mode/video_mode_edits.dart';
import 'package:fluvie_editor/src/video_mode/video_timebase.dart';

part 'video_razor_shared.part.dart';
part 'video_razor_trim.part.dart';
part 'video_razor_audio.part.dart';

/// Splits the bar [barId] at absolute [frame] into two elements.
///
/// The head keeps the element's identity, its z-position and the head of its
/// window; the tail is a new element with the same props, the rest of the
/// window, and a trim that picks up exactly where the head left off. Without
/// that trim shift the tail would restart the source from its beginning: a
/// jump cut nobody asked for.
///
/// Returns null for a bar there is nothing to split (a scene block, an id the
/// model does not know), and a refusal naming the reason where a split would
/// have to guess.
///
/// [tailId] names the new element; a caller cutting several bars at once mints
/// its whole batch up front (`EditorDocument.nextIds`) so the ids stay distinct
/// and redo stays deterministic. [mergeGroup] coalesces such a batch into one
/// undo step.
VideoLaneEdit? videoBarRazored(
  VideoLaneModel model,
  String barId,
  int frame, {
  required EditorDocument document,
  String? tailId,
  String? mergeGroup,
}) {
  if (model.isLocked(barId)) {
    return const VideoLaneEdit.refused('Unlock the lane before editing it.');
  }
  final audio = model.audioBars[barId];
  if (audio != null) {
    return audioBarRazored(
      model,
      barId,
      frame,
      document: document,
      tailId: tailId,
      mergeGroup: mergeGroup,
    );
  }

  final overlay = model.overlayBars[barId];
  if (overlay != null) {
    if (frame <= overlay.window.start || frame >= overlay.window.end) {
      return const VideoLaneEdit.refused('Put the playhead inside the overlay to razor it.');
    }
    final element = document.elementJson(overlay.elementId)!;
    final head = {
      ...element,
      'show': {'from': '${overlay.window.start}f', 'to': '${frame}f'},
    };
    final tail = {
      ...element,
      'show': {'from': '${frame}f', 'to': '${overlay.window.end}f'},
    }..remove('anchor');
    if (element['type'] == 'Clip') {
      final split = _splitTrim(
        element,
        fps: model.fps,
        elapsed: (frame - overlay.window.start) / model.fps,
        remaining: (overlay.window.end - frame) / model.fps,
      );
      if (split is _TrimRefusal) return VideoLaneEdit.refused(split.note);
      head['trim'] = (split as _TrimSplit).headTrim;
      tail['trim'] = split.tailTrim;
      if (split.headSpeed != null) head['speed'] = split.headSpeed;
      if (split.tailSpeed != null) tail['speed'] = split.tailSpeed;
    }
    _splitAudio(
      element,
      head,
      tail,
      frame - overlay.window.start,
      overlay.window.durationFrames,
      model.fps,
    );
    return VideoLaneEdit.command(
      RazorElementCommand(
        id: overlay.elementId,
        tailId: tailId ?? document.nextId(),
        mergeGroup: mergeGroup,
        head: head,
        tail: tail,
      ),
    );
  }
  final binding = model.elementBars[barId];
  if (binding == null) return null;
  if (binding.members.isNotEmpty) {
    return _sharedRazored(model, binding, frame, document, tailId, mergeGroup);
  }
  // Landing on the first or last frame is a miss, not a cut: one half would
  // be nothing at all, which is a delete wearing a razor's clothes.
  final window = binding.window;
  if (frame <= window.start || frame >= window.end) {
    return const VideoLaneEdit.refused('Put the playhead inside the clip to razor it.');
  }
  final element = document.elementJson(binding.elementId);
  if (element == null) return null;
  final sceneStart = videoElementOwner(
    document,
    introspectTimeline(document.spec.build()),
    binding.elementId,
  ).start;
  final head = <String, Object?>{
    ...element,
    'show': {'from': '${window.start - sceneStart}f', 'to': '${frame - sceneStart}f'},
  };
  final tail = <String, Object?>{
    ...element,
    'show': {'from': '${frame - sceneStart}f', 'to': '${window.end - sceneStart}f'},
  }..remove('anchor');
  if (element['type'] == 'Clip') {
    final split = _splitTrim(
      element,
      fps: model.fps,
      elapsed: (frame - window.start) / model.fps,
      remaining: (window.end - frame) / model.fps,
    );
    switch (split) {
      case _TrimRefusal(:final note):
        return VideoLaneEdit.refused(note);
      case _TrimSplit(:final headTrim, :final tailTrim):
        head['trim'] = headTrim;
        tail['trim'] = tailTrim;
        if (split.headSpeed != null) head['speed'] = split.headSpeed;
        if (split.tailSpeed != null) tail['speed'] = split.tailSpeed;
    }
  }
  _splitAudio(element, head, tail, frame - window.start, window.durationFrames, model.fps);
  if (model.hasClipTransition(barId)) {
    return transitionClipRazored(
      model,
      binding.elementId,
      tailId ?? document.nextId(),
      head,
      tail,
      mergeGroup: mergeGroup,
    );
  }
  return VideoLaneEdit.command(
    RazorElementCommand(
      id: binding.elementId,
      tailId: tailId ?? document.nextId(),
      head: head,
      tail: tail,
      mergeGroup: mergeGroup,
    ),
  );
}
