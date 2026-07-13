import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart' show Video;
import 'package:fluvie_presenter/src/player/live_scene_player.dart';

/// The presenter: hand it a [Video] and present it.
///
/// ```dart
/// runApp(FluvieSlides(video));
/// ```
///
/// This is the Phase 1 skeleton of the viewer — it plays the video's first
/// scene live on a flat stage. Stepping (`Stop`), input, the sidebar, notes,
/// and the speaker window arrive phase by phase; the constructor already
/// carries the minimal config surface so callers never migrate.
final class FluvieSlides extends StatelessWidget {
  /// Presents [video].
  const FluvieSlides(
    this.video, {
    this.showSidebar = false,
    this.showNotes = false,
    this.startFullscreen = false,
    super.key,
  });

  /// The presentation: a plain fluvie composition, one scene per slide.
  final Video video;

  /// Whether the slide sidebar starts visible.
  final bool showSidebar;

  /// Whether the speaker-notes panel starts visible.
  final bool showNotes;

  /// Whether presenting starts in fullscreen.
  final bool startFullscreen;

  @override
  Widget build(BuildContext context) {
    final stage = ColoredBox(
      color: const Color(0xFF101014),
      child: Center(child: LiveScenePlayer(video: video)),
    );
    // The presenter can be someone's whole runApp: give the stage a text
    // direction when no app shell above provides one.
    return Directionality.maybeOf(context) == null
        ? Directionality(textDirection: TextDirection.ltr, child: stage)
        : stage;
  }
}
