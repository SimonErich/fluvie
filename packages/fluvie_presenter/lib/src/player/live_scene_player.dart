import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart' as fluvie;
import 'package:fluvie/fluvie.dart' show LivePlaybackController, LivePlayer, Video;

/// Plays one scene of a [video] live, at the scene's own place on the
/// resolved timeline.
///
/// This is the presenter's only doorway into fluvie playback: it mounts
/// fluvie's [LivePlayer], reads the scene's absolute bounds through timeline
/// introspection, and plays exactly that segment — then holds the last
/// frame. Everything above it (slides, steps, chrome) talks to this wrapper,
/// so future fluvie playback changes land in one file.
///
/// ```dart
/// LiveScenePlayer(video: video);                 // plays scene 0, then holds
/// LiveScenePlayer(video: video, sceneIndex: 2);  // a later slide
/// ```
final class LiveScenePlayer extends StatefulWidget {
  /// Plays [video]'s scene at [sceneIndex] (default: the first).
  ///
  /// A [controller] passed in stays under the caller's control (and is not
  /// disposed here); without one the player owns a clock bounded to the
  /// video. [autoPlay] starts the scene segment on mount.
  const LiveScenePlayer({
    required this.video,
    this.sceneIndex = 0,
    this.controller,
    this.autoPlay = true,
    super.key,
  });

  /// The composition the scene belongs to.
  final Video video;

  /// Which scene to play, as an index into the video's scene list.
  final int sceneIndex;

  /// The clock to drive, or `null` to let the player own one.
  final LivePlaybackController? controller;

  /// Whether the scene segment starts playing on mount.
  final bool autoPlay;

  @override
  State<LiveScenePlayer> createState() => _LiveScenePlayerState();
}

final class _LiveScenePlayerState extends State<LiveScenePlayer> {
  late final LivePlaybackController _controller =
      widget.controller ??
      LivePlaybackController(fps: widget.video.fps, totalFrames: widget.video.totalFrames);

  bool get _ownsController => widget.controller == null;

  @override
  void initState() {
    super.initState();
    final span = fluvie.introspectTimeline(widget.video).scenes[widget.sceneIndex].span;
    if (widget.autoPlay) {
      // The range future resolves when the scene's last frame holds; the
      // player has nothing to do at that point, so nothing awaits it.
      unawaited(_controller.playRange(span.start, span.end - 1));
    } else {
      _controller.hold(span.start);
    }
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LivePlayer(
    controller: _controller,
    child: FittedBox(
      child: SizedBox(
        width: widget.video.width.toDouble(),
        height: widget.video.height.toDouble(),
        child: widget.video,
      ),
    ),
  );
}
