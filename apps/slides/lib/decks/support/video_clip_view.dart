import 'package:flutter/widgets.dart';
import 'package:slides/decks/support/video_clip_view_stub.dart'
    if (dart.library.js_interop) 'package:slides/decks/support/video_clip_view_web.dart';

/// A real, sounding video inside a slide.
///
/// fluvie's `Clip` is for rendering to a file: in live playback it has no
/// resolver and audio only exists in the encoder's mix. A presentation
/// wants an actual player, so on the web this embeds an HTML `video`
/// element (with controls and sound) as a platform view — live slides
/// allow those. Off the web it shows a flat placeholder.
///
/// The player runs on its own clock, not the slide's frame clock; for a
/// talk that is the point — you press play when you are ready.
final class VideoClipView extends StatelessWidget {
  /// Shows the bundled video at [assetPath] (e.g. `assets/videos/demo.mp4`).
  const VideoClipView({required this.assetPath, required this.label, super.key});

  /// The bundled asset path of the mp4.
  final String assetPath;

  /// What the clip shows; the placeholder and the platform view label it.
  final String label;

  @override
  Widget build(BuildContext context) => buildVideoClipView(assetPath, label);
}
