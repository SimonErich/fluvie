// Compiled, tested snippets for the live-playback docs. They live here, not
// hand-typed in Markdown, so the documentation never drifts from a real API.
// Each `#docregion` flows into one fence via a `<!-- code-excerpt -->` marker.

// The playback snippets deliberately repeat the receiver so each line reads
// standalone in its docs fence; a cascade would hide the API being named.
// ignore_for_file: cascade_invocations
import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';

/// A live player over a composition: the ticker drives the same frame clock
/// capture steps, so what plays is what renders.
// #docregion live-player
class PlayingVideo extends StatefulWidget {
  const PlayingVideo({required this.video, this.previewMedia = false, super.key});

  final Video video;
  final bool previewMedia;

  @override
  State<PlayingVideo> createState() => _PlayingVideoState();
}

class _PlayingVideoState extends State<PlayingVideo> {
  late LivePlaybackController playback;

  @override
  void initState() {
    super.initState();
    playback = createPlayback();
  }

  LivePlaybackController createPlayback() =>
      LivePlaybackController(fps: widget.video.fps, totalFrames: widget.video.totalFrames)..play();

  @override
  void didUpdateWidget(PlayingVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.fps != widget.video.fps ||
        oldWidget.video.totalFrames != widget.video.totalFrames) {
      playback.dispose();
      playback = createPlayback();
    }
  }

  @override
  void dispose() {
    playback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LivePlayer(
    controller: playback,
    child: widget.previewMedia ? PreviewMediaScope(composition: widget.video) : widget.video,
  );
}
// #enddocregion live-player

/// The same player with the composition's media pre-decoded, so a `Clip` paints
/// real frames through the capture painter instead of its placeholder.
// #docregion preview-media
Widget playLiveWithMedia(Video video) => PlayingVideo(video: video, previewMedia: true);
// #enddocregion preview-media

/// The playback surface: exact seeks, held states, and a segment that stops
/// on its end frame.
// #docregion playback-controls
Future<void> driveIt(LivePlaybackController playback) async {
  playback.play(); // free-run from the current frame
  playback.pause(); // freeze right here
  playback.seek(120); // land exactly on frame 120
  playback.hold(120); // land there and stay (back-navigation wants this)
  playback.rate = 1.5; // one-and-a-half speed, rebased without a jump
  await playback.playRange(120, 180); // play a segment, hold its last frame
}
// #enddocregion playback-controls

/// Static timeline introspection: scene bounds and element windows as plain
/// frame spans, without mounting anything.
// #docregion introspection
void whereThingsAre(Video video, Anchor logo) {
  final introspection = introspectTimeline(video);
  final scene = introspection.scenes[1];
  debugPrint('scene 1 runs ${scene.span.start}..${scene.span.end}');

  final element = introspection.elementForAnchor(logo)!;
  debugPrint('the logo is alive ${element.window}');
  debugPrint('its entrance plays ${element.enterSpan}');
}

// #enddocregion introspection

/// Dynamic live content: a subtree that mounts mid-playback and animates in
/// from that moment, detached from the composition's resolved plan.
// #docregion local-motion-scope
Widget lateArrival({required bool revealed}) => LocalMotionScope(
  child: revealed ? const Text('surprise!').animate([Animation.fadeIn()]) : const SizedBox.shrink(),
);
// #enddocregion local-motion-scope

/// A canvas editor's drag preview: per-element placement replacements over a
/// built composition, without rebuilding it.
// #docregion placed-overrides
Widget dragPreview(Video video, Map<String, Placement> live, LivePlaybackController held) =>
    LivePlayer(
      controller: held,
      child: PlacedOverrides(overrides: live, child: video),
    );
// #enddocregion placed-overrides
