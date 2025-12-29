import 'package:flutter/material.dart';
import 'sequence.dart';
import '../domain/render_config.dart';

/// A sequence that renders text.
///
/// Use this to add titles, subtitles, or other text elements to your
/// video composition.
///
/// Example:
/// ```dart
/// TextSequence(
///   startFrame: 30,
///   durationInFrames: 90,
///   text: 'Welcome!',
///   style: TextStyle(
///     fontSize: 48,
///     color: Colors.white,
///     fontWeight: FontWeight.bold,
///   ),
/// )
/// ```
class TextSequence extends Sequence {
  /// The text to display.
  final String text;

  /// The style to use for the text.
  final TextStyle? style;

  /// Creates a text sequence.
  const TextSequence({
    super.key,
    required super.startFrame,
    required super.durationInFrames,
    required this.text,
    this.style,
    super.child = const SizedBox(),
  });

  @override
  Widget build(BuildContext context) {
    return Text(text, style: style);
  }

  @override
  SequenceConfig toSequenceConfig() {
    return SequenceConfig.text(
      startFrame: startFrame,
      durationInFrames: durationInFrames,
      text: text,
    );
  }
}
