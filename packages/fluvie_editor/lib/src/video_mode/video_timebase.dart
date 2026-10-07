import 'package:fluvie/fluvie.dart'
    show FrameSpan, SceneIntrospection, TimeScope, TimelineIntrospection, introspectTimeline;
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:meta/meta.dart';

/// The video mode's one clock reference: the whole composition's frame
/// count and each scene's absolute span, read straight off the same
/// [introspectTimeline] resolution the renderer plays — never a second
/// editor-side computation of scene math.
///
/// Slides mode and video mode meet here: a slide-local frame is
/// `absolute - sceneSpans[scene].start`, so the per-scene playhead and the
/// absolute one can never disagree.
@immutable
final class VideoTimebase {
  /// Builds the timebase from an already-made [introspection].
  VideoTimebase.fromIntrospection(TimelineIntrospection introspection)
    : fps = introspection.fps,
      totalFrames = introspection.totalFrames,
      sceneSpans = List.unmodifiable([
        for (final scene in introspection.scenes) scene.span,
      ]),
      _settleFrames = List.unmodifiable(_settleFramesOf(introspection.scenes));

  /// Builds the timebase of [document]'s whole composition.
  factory VideoTimebase.of(EditorDocument document) =>
      VideoTimebase.fromIntrospection(introspectTimeline(document.spec.build()));

  /// Frames per second of the composition.
  final int fps;

  /// The video's total length in frames, transition overlaps included.
  final int totalFrames;

  /// Each scene's absolute frame span, in playback order.
  final List<FrameSpan> sceneSpans;

  /// Each scene's settled frame, in playback order (see [settleFrameOf]).
  final List<int> _settleFrames;

  /// The scene under [frame]: the last scene whose span has started (the
  /// incoming scene wins inside a transition overlap), clamped to the
  /// video's scenes.
  int sceneAt(int frame) {
    var scene = 0;
    for (var i = 0; i < sceneSpans.length; i++) {
      if (sceneSpans[i].start <= frame) scene = i;
    }
    return scene;
  }

  /// The first frame at which scene [scene] is fully settled on the absolute
  /// clock: past the incoming transition's blend window and every entrance
  /// animation, so its on-stage geometry matches the compositor's render.
  ///
  /// This is the video-mode counterpart of the slides deriver's settle
  /// frame, read off the same introspection: an editing seek parks here, not
  /// at [sceneSpans]`.start`, where an incoming `slide`/`zoom`/`wipe` blend
  /// still displaces the scene and the gizmo would grab empty space. The
  /// scene index clamps to the video's scenes, like [sceneAt].
  int settleFrameOf(int scene) => _settleFrames[scene.clamp(0, _settleFrames.length - 1)];

  static List<int> _settleFramesOf(List<SceneIntrospection> scenes) => [
    for (var s = 0; s < scenes.length; s++) _settleFrame(s, scenes),
  ];

  /// Scene [s]'s settled frame: the latest of its span start, its incoming
  /// overlap end, and every entrance end, never past its own last frame.
  static int _settleFrame(int s, List<SceneIntrospection> scenes) {
    final span = scenes[s].span;
    var settle = span.start;
    // An overlapping incoming transition holds the predecessor live through
    // the blend, whose window ends exactly where the predecessor's span does.
    if (s > 0 && scenes[s - 1].span.end > settle) settle = scenes[s - 1].span.end;
    // Each entrance animation settles at the end of its enter span.
    for (final element in scenes[s].elements) {
      final enter = element.enterSpan;
      if (enter != null && enter.end > settle) settle = enter.end;
    }
    final last = span.end - 1;
    return settle > last ? last : settle;
  }
}

/// Resolves an audio track's authored times (trim, fades, an sfx start)
/// against its owner's span — a scene's, or the whole video's.
final class OwnerFrameScope implements TimeScope {
  /// Creates the scope over [owner] at [fps].
  const OwnerFrameScope(this.fps, this.owner);

  @override
  final int fps;

  /// The owner's absolute frame span.
  final FrameSpan owner;

  @override
  int get startFrame => owner.start;

  @override
  int get durationFrames => owner.durationFrames;

  @override
  TimeScope? get parent => null; // coverage:ignore-line TimeScope obligation resolution uses the nearest scope only
}
