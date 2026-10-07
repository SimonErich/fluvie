import 'package:fluvie/fluvie.dart' show FluvieTimingError, VideoSpec;
import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/video_mode/video_lane_model.dart';
import 'package:fluvie_editor/src/video_mode/video_mode_edits.dart';

/// Retimes slide [scene] to [durationFrames], clamping the windows inside it
/// and moving everything after it.
///
/// A slide's duration is the master clock: lengthening it pushes every later
/// slide along and lengthens the video, and shortening it pulls them back.
/// That is why this is one command — the retime and the window clamps it
/// forces are one thing the author did.
///
/// A duration the engine would refuse is refused here, in the engine's own
/// words, rather than written into a document that would then fail to render.
VideoLaneEdit? videoSceneRetimed(
  VideoLaneModel model,
  int scene,
  int durationFrames, {
  required EditorDocument document,
  String? mergeGroup,
}) {
  if (scene < 0 || scene >= model.timebase.sceneSpans.length) return null;
  if (durationFrames < 1) {
    return const VideoLaneEdit.refused('A slide needs at least one frame.');
  }
  if (durationFrames == model.timebase.sceneSpans[scene].durationFrames) return null;
  final commands = <EditorCommand>[
    UpdateSceneCommand(
      index: scene,
      patch: {'duration': '${durationFrames}f'},
      mergeGroup: mergeGroup,
    ),
  ];
  final clamped = <String>[];
  for (final id in document.elementIdsInScene(scene)) {
    final command = _clampWindow(document, id, durationFrames);
    if (command == null) continue;
    commands.add(command);
    clamped.add(id);
  }
  final command = SequenceCommand(commands, label: 'Retime slide', mergeGroup: mergeGroup);
  // Ask the engine before writing, not after: the offset resolver is the
  // authority on whether a slide can hold its own transitions, and its message
  // says more than anything this could invent.
  final refusal = _engineRefusal(command.apply(document));
  if (refusal != null) return VideoLaneEdit.refused(refusal);
  if (clamped.isEmpty) return VideoLaneEdit.command(command);
  return VideoLaneEdit.clamped(
    command,
    'Clamped ${clamped.length == 1 ? '' : '${clamped.length} windows: '}'
    '${clamped.join(', ')} into the shorter slide.',
  );
}

/// The command that fits element [id]'s window inside a slide of
/// [durationFrames], or null when it already fits.
///
/// A window whose start is past the new end is not a window at all, so the key
/// goes rather than being written inverted: the element keeps its place on the
/// canvas and loses its timing, which is the honest half of the two.
EditorCommand? _clampWindow(EditorDocument document, String id, int durationFrames) {
  final element = document.elementJson(id);
  final show = element?['show'];
  if (element == null || show is! Map<String, Object?>) return null;
  final from = _frames(show['from']) ?? 0;
  final to = _frames(show['to']) ?? durationFrames;
  if (from < durationFrames && to <= durationFrames) return null;
  if (from >= durationFrames) {
    return ReplaceElementCommand(id: id, element: {...element}..remove('show'));
  }
  return SetShowWindowCommand(id: id, fromFrames: from, toFrames: durationFrames);
}

/// The engine's own refusal for [document], or null when it would render.
String? _engineRefusal(EditorDocument document) {
  try {
    // Reading the length is what runs the offset resolver: building the widget
    // alone resolves nothing, because the offsets are computed on demand.
    VideoSpec.fromJson(document.toJson()).build().totalFrames;
  } on FluvieTimingError catch (error) {
    return error.message;
  }
  return null;
}

/// A `<n>f` time in frames, or null for anything else (a seconds or relative
/// window is not this function's to rewrite).
int? _frames(Object? raw) {
  if (raw is! String || !raw.endsWith('f')) return null;
  return int.tryParse(raw.substring(0, raw.length - 1));
}
