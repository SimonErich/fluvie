import 'package:fluvie/fluvie.dart'
    show EffectSpecKind, FrameSpan, TimelineIntrospection, decodeTime, introspectTimeline;
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/timeline/keyframe_stop_math.dart';
import 'package:fluvie_editor/src/transitions/transition_edits.dart';
import 'package:fluvie_editor/src/video_mode/video_effect_lane_binding.dart';
import 'package:fluvie_editor/src/video_mode/video_lane_bindings.dart';
import 'package:fluvie_editor/src/video_mode/video_timebase.dart';
import 'package:fluvie_editor/src/widgets/track_timeline/timeline_bar.dart';
import 'package:fluvie_editor/src/widgets/track_timeline/timeline_diamond.dart';
import 'package:fluvie_editor/src/widgets/track_timeline/timeline_marker.dart';
import 'package:fluvie_editor/src/widgets/track_timeline/timeline_track.dart';

part 'video_lane_builder.dart';
part 'video_lane_effects.dart';
part 'video_lane_structure.part.dart';
part 'video_lane_overlays.part.dart';
part 'video_lane_elements.part.dart';
part 'video_lane_audio.part.dart';

/// The timeline row id of the declared lane [laneId].
///
/// Prefixed, because a lane id and an element id live in the same namespace of
/// row ids and an author is free to name a lane after a clip.
String laneRowId(String laneId) => 'lane:$laneId';

/// The lane id behind the row id [rowId], or null when the row is not a
/// declared lane.
String? laneIdOfRow(String rowId) =>
    rowId.startsWith('lane:') ? rowId.substring('lane:'.length) : null;

/// The track-timeline model of the whole video: a scenes lane heading the
/// absolute ruler (boundaries as markers), one lane per clip or explicitly
/// windowed element positioned on the introspected window, and one lane
/// per audio track — video-level tracks from their `at` (or zero) for their
/// trim length, scene-level tracks offset by their scene start.
///
/// Every absolute frame comes from the same [introspectTimeline] resolution
/// the renderer plays (through [VideoTimebase]); the model never recomputes
/// scene math. Like the slide model, it is display data plus the bindings
/// that turn a lane edit back into a document command, strictly one
/// direction: document in, commands out, the next build starts fresh.
final class VideoLaneModel {
  VideoLaneModel._({
    required this.document,
    required this.tracks,
    required this.markers,
    required this.elementBars,
    required this.audioBars,
    required this.overlayBars,
    required this.effectBars,
    required this.effectDiamonds,
    required this.transitionBars,
    required this.timebase,
    required this._lockedMembers,
  });

  /// Builds the model for [document], colored through [palette].
  ///
  /// The palette decides nothing but how bars are painted, so a caller that
  /// never paints — a registry verb reading the lanes to find what it can act
  /// on — takes [VideoLanePalette.unpainted] and ignores the question.
  factory VideoLaneModel.build({
    required EditorDocument document,
    VideoLanePalette palette = VideoLanePalette.unpainted,
  }) {
    final introspection = introspectTimeline(document.spec.build());
    final builder = _VideoLaneBuilder(
      document,
      VideoTimebase.fromIntrospection(introspection),
      introspection,
      palette,
    )..build();
    return VideoLaneModel._(
      document: document,
      tracks: List.unmodifiable(builder.tracks),
      markers: List.unmodifiable(builder.markers),
      elementBars: Map.unmodifiable(builder.elementBars),
      audioBars: Map.unmodifiable(builder.audioBars),
      overlayBars: Map.unmodifiable(builder.overlayBars),
      effectBars: Map.unmodifiable(builder.effectBars),
      effectDiamonds: Map.unmodifiable(builder.effectDiamonds),
      transitionBars: Map.unmodifiable(builder.transitionBars),
      timebase: builder.timebase,
      lockedMembers: {
        for (final entry in builder.elementBars.entries)
          if ((entry.value.members.isEmpty ? [entry.value] : entry.value.members).any(
            (member) => document.spec.lanes.any(
              (lane) => lane.locked && lane.id == document.elementJson(member.elementId)?['lane'],
            ),
          ))
            entry.key,
      },
    );
  }

  /// The immutable source snapshot used to validate structural edits.
  final EditorDocument document;

  /// The rows: the scenes lane, element lanes scene by scene (topmost
  /// first, like the layers panel), then audio lanes (video-level first).
  final List<TimelineTrack> tracks;

  /// One boundary marker per scene start past the first.
  final List<TimelineMarker> markers;

  /// The document join per element bar id (`el:<elementId>`).
  final Map<String, VideoElementLaneBinding> elementBars;

  /// The document join per audio bar id (`audio:v:<i>` and
  /// `audio:s:<scene>:<i>`).
  final Map<String, VideoAudioLaneBinding> audioBars;

  /// The document join per overlay bar id (`overlay:<elementId>`).
  final Map<String, VideoOverlayLaneBinding> overlayBars;

  /// The document join per effect bar id (`fx:<elementId>:<index>`).
  final Map<String, VideoEffectLaneBinding> effectBars;

  /// The document join per effect diamond id
  /// (`fx:<elementId>:<index>:<param>:k<stop>`).
  final Map<String, VideoEffectDiamondBinding> effectDiamonds;

  /// The paired clip transition behind each `transition:<scene>:<index>` bar.
  final Map<String, VideoTransitionBinding> transitionBars;

  /// The whole-video clock reference the lanes are positioned on.
  final VideoTimebase timebase;
  final Set<String> _lockedMembers;

  /// The deck's frames per second.
  int get fps => timebase.fps;

  /// The video's total length in frames.
  int get totalFrames => timebase.totalFrames;

  /// Whether anything beyond the scenes lane exists — false is the empty
  /// state (no clips, no windows, no audio).
  bool get hasLanes => tracks.length > 1;

  /// Whether the row holding [barId] is locked against timeline edits.
  bool isLocked(String barId) =>
      _lockedMembers.contains(barId) ||
      tracks.any(
        (track) => track.locked && track.bars.any((bar) => bar.id == barId),
      );

  /// Whether this clip is constrained by a paired transition.
  bool hasClipTransition(String barId) {
    final id = elementBars[barId]?.elementId;
    return id != null &&
        transitionBars.values.any((edge) => edge.spec.outgoing == id || edge.spec.incoming == id);
  }

  /// The actual row of a bar, including declared shared lanes.
  String? rowOf(String barId) {
    for (final track in tracks) {
      if (track.bars.any((bar) => bar.id == barId)) return track.id;
    }
    return null;
  }
}
