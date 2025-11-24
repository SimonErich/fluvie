import 'package:flutter/material.dart';
import '../domain/renderable.dart';
import '../domain/render_config.dart';
import 'clip.dart';

/// A clip that renders text.
///
/// Use this to add titles, subtitles, or other text elements.
class TextClip extends Clip {
  /// The text to display.
  final String text;

  /// The style to use for the text.
  final TextStyle? style;

  const TextClip({
    super.key,
    required super.startFrame,
    required super.durationInFrames,
    required this.text,
    this.style,
    super.child = const SizedBox(),
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style,
    );
  }
  
  @override
  ClipConfig toClipConfig() {
     return ClipConfig(
      startFrame: startFrame,
      durationInFrames: durationInFrames,
      // TODO: Add text specific props if needed
    );
  }
}
