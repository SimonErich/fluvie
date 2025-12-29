import 'package:flutter/widgets.dart';

import '../../presentation/fade_text.dart';
import '../../presentation/time_consumer.dart';
import '../../presentation/video_composition.dart';

/// A text widget that reveals characters one by one like a typewriter.
///
/// [TypewriterText] animates text appearance by progressively revealing
/// characters based on the current frame.
///
/// Example:
/// ```dart
/// TypewriterText(
///   'Hello World',
///   style: TextStyle(fontSize: 24, color: Colors.white),
///   startFrame: 30,
///   charsPerSecond: 20,
/// )
/// ```
class TypewriterText extends StatelessWidget {
  /// The text to display.
  final String text;

  /// The style to apply to the text.
  final TextStyle? style;

  /// The frame at which to start typing.
  final int startFrame;

  /// Number of characters revealed per second.
  ///
  /// This is converted to characters per frame based on the video's FPS.
  final double charsPerSecond;

  /// Whether to show a blinking cursor.
  final bool showCursor;

  /// The cursor character to display.
  final String cursorChar;

  /// Duration of cursor blink in frames.
  final int cursorBlinkFrames;

  /// How the text should be aligned horizontally.
  final TextAlign? textAlign;

  /// The maximum number of lines for the text.
  final int? maxLines;

  /// How visual overflow should be handled.
  final TextOverflow? overflow;

  /// Creates a typewriter text widget.
  const TypewriterText(
    this.text, {
    super.key,
    this.style,
    this.startFrame = 0,
    this.charsPerSecond = 15,
    this.showCursor = true,
    this.cursorChar = '|',
    this.cursorBlinkFrames = 15,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return TimeConsumer(
      builder: (context, frame, _) {
        final composition = VideoComposition.of(context);
        final fps = composition?.fps ?? 30;

        // Calculate characters per frame
        final charsPerFrame = charsPerSecond / fps;

        // Calculate how many frames since start
        final elapsedFrames = frame - startFrame;

        if (elapsedFrames < 0) {
          // Before typing starts, show nothing or just cursor
          return FadeText(
            showCursor ? cursorChar : '',
            style: style,
            textAlign: textAlign,
            maxLines: maxLines,
            overflow: overflow,
          );
        }

        // Calculate how many characters to show
        final charsToShow = (elapsedFrames * charsPerFrame).floor();
        final visibleChars = charsToShow.clamp(0, text.length);
        final visibleText = text.substring(0, visibleChars);

        // Calculate cursor visibility (blinking)
        String cursorDisplay = '';
        if (showCursor) {
          final cursorPhase = (frame ~/ cursorBlinkFrames) % 2;
          if (cursorPhase == 0 || visibleChars < text.length) {
            cursorDisplay = cursorChar;
          }
        }

        return FadeText(
          visibleText + cursorDisplay,
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
        );
      },
    );
  }

  /// Calculates the total duration of the typewriter animation in frames.
  int totalDuration(int fps) {
    final charsPerFrame = charsPerSecond / fps;
    return (text.length / charsPerFrame).ceil();
  }
}
