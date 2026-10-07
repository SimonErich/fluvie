import 'dart:ui' show Color;

import 'package:fluvie/fluvie.dart' show FrameSpan;
import 'package:meta/meta.dart';

/// The lane colors the video timeline paints with: scene blocks, element
/// (clip and window) lanes, music beds, and sound effects.
@immutable
final class VideoLanePalette {
  /// Creates the palette.
  const VideoLanePalette({
    required this.scene,
    required this.element,
    required this.music,
    required this.sfx,
  });

  /// The scene-block color.
  final Color scene;

  /// The element-lane color.
  final Color element;

  /// The music-bed color.
  final Color music;

  /// The sound-effect color.
  final Color sfx;

  /// The palette a caller takes when it never paints: one flat colour for
  /// every lane, because the question does not arise.
  static const unpainted = VideoLanePalette(
    scene: Color(0xFF000000),
    element: Color(0xFF000000),
    music: Color(0xFF000000),
    sfx: Color(0xFF000000),
  );

  @override
  bool operator ==(Object other) =>
      other is VideoLanePalette &&
      other.scene == scene &&
      other.element == element &&
      other.music == music &&
      other.sfx == sfx;

  @override
  int get hashCode => Object.hash(VideoLanePalette, scene, element, music, sfx);
}

/// How an audio track is placed in time — what a lane drag may honestly
/// rewrite.
enum VideoAudioAt {
  /// The track starts with its owner (every music bed, and an sfx without
  /// `at`); the spec has no key to move it, so a lane drag is refused.
  ownerStart,

  /// An sfx placed by a time trigger (`{kind: at, time}`); a lane drag
  /// rewrites the time.
  time,

  /// An sfx placed by a non-time trigger (beat, whenEnds, ...); a lane
  /// drag would destroy the authored trigger, so it is refused.
  trigger,
}

/// Joins one element lane back to the document: the element, its scene, and
/// the absolute frames involved — [window] IS the introspected alive-window,
/// so lane edits subtract [sceneSpan]'s start to write scene-relative
/// `show` bounds.
@immutable
final class VideoElementLaneBinding {
  /// Creates the binding.
  const VideoElementLaneBinding({
    required this.elementId,
    required this.scene,
    required this.sceneSpan,
    required this.window,
    required this.hasWindow,
    this.inSteps = false,
    this.isGrouped = false,
    this.members = const [],
  });

  /// The document element the lane shows.
  final String elementId;

  /// The scene holding the element.
  final int scene;

  /// The scene's absolute frame span.
  final FrameSpan sceneSpan;

  /// The element's alive-window in absolute video frames.
  final FrameSpan window;

  /// Whether the element carries an explicit `show` key (false for a clip
  /// alive its whole scene).
  final bool hasWindow;

  /// Whether the scene's build `steps` name this element — a cross-scene
  /// move then strips the id and says so.
  final bool inSteps;

  /// Whether the element is a group child; it moves scenes with its group,
  /// never alone.
  final bool isGrouped;

  /// Individual scene windows when this row represents one shared chain.
  /// Empty for ordinary elements. The chain keeps one bar identity: its first member.
  final List<VideoElementLaneBinding> members;
}

/// Joins one audio lane back to the document: which `audio` list, which
/// entry, and the resolved frames its bar shows.
@immutable
final class VideoAudioLaneBinding {
  /// Creates the binding.
  const VideoAudioLaneBinding({
    required this.scene,
    required this.index,
    required this.isSfx,
    required this.span,
    required this.at,
    this.trimFromFrames,
    this.trimToFrames,
  });

  /// The owning scene, or null for the video-level list.
  final int? scene;

  /// The track's position in its owner's `audio` list.
  final int index;

  /// Whether the track is a one-shot sfx rather than a music bed.
  final bool isSfx;

  /// The absolute frames the lane's bar covers.
  final FrameSpan span;

  /// How the track is placed in time.
  final VideoAudioAt at;

  /// The authored trim start in source frames, or null when untrimmed.
  final int? trimFromFrames;

  /// The authored trim end in source frames, or null when untrimmed.
  final int? trimToFrames;
}

/// Joins one overlay lane back to the document: the element and the absolute
/// frames its bar spans.
///
/// No scene span, because an overlay is in none: its window is measured
/// against the whole video, so a lane edit writes absolute frames and never
/// clamps into a slide.
@immutable
final class VideoOverlayLaneBinding {
  /// Creates the binding.
  const VideoOverlayLaneBinding({
    required this.elementId,
    required this.window,
    this.home,
  });

  /// The overlay the lane shows.
  final String elementId;

  /// Its alive-window in absolute video frames.
  final FrameSpan window;

  /// The slide the editor draws it on, or null when nothing homed it.
  final int? home;
}
