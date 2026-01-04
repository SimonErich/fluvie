import 'package:flutter/widgets.dart';

/// A widget that wraps content in a polaroid-style frame.
///
/// [PolaroidFrame] creates a classic instant photo look with a white
/// border and optional caption at the bottom.
///
/// Example:
/// ```dart
/// PolaroidFrame(
///   size: Size(300, 350),
///   caption: 'Summer 2024',
///   rotation: 0.05,
///   child: Image.asset('photo.jpg'),
/// )
/// ```
class PolaroidFrame extends StatelessWidget {
  /// The content to display inside the frame.
  final Widget child;

  /// Optional caption text below the image.
  final String? caption;

  /// Size of the entire polaroid (including frame).
  final Size size;

  /// Color of the frame (default white).
  final Color frameColor;

  /// Padding inside the frame around the image.
  final double framePadding;

  /// Extra padding at the bottom for the caption area.
  final double bottomPadding;

  /// Shadow blur radius.
  final double shadowBlur;

  /// Shadow offset.
  final Offset shadowOffset;

  /// Shadow color.
  final Color shadowColor;

  /// Rotation angle in radians.
  final double rotation;

  /// Style for the caption text.
  final TextStyle? captionStyle;

  /// Creates a polaroid frame.
  const PolaroidFrame({
    super.key,
    required this.child,
    this.caption,
    this.size = const Size(300, 350),
    this.frameColor = const Color(0xFFFFFFF0), // Off-white
    this.framePadding = 12,
    this.bottomPadding = 40,
    this.shadowBlur = 15,
    this.shadowOffset = const Offset(0, 5),
    this.shadowColor = const Color(0x40000000),
    this.rotation = 0.0,
    this.captionStyle,
  });

  /// Creates a polaroid frame with a slight random tilt.
  const PolaroidFrame.tilted({
    super.key,
    required this.child,
    this.caption,
    this.size = const Size(300, 350),
    this.frameColor = const Color(0xFFFFFFF0),
    this.framePadding = 12,
    this.bottomPadding = 40,
    this.shadowBlur = 15,
    this.shadowOffset = const Offset(0, 5),
    this.shadowColor = const Color(0x40000000),
    double tiltDegrees = 5,
    this.captionStyle,
  }) : rotation = tiltDegrees * 3.14159 / 180;

  @override
  Widget build(BuildContext context) {
    // Calculate image area size
    final imageWidth = size.width - (framePadding * 2);
    final imageHeight = size.height - (framePadding * 2) - bottomPadding;

    Widget frame = Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color: frameColor,
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: shadowBlur,
            offset: shadowOffset,
          ),
        ],
      ),
      child: Column(
        children: [
          // Image area
          Padding(
            padding: EdgeInsets.all(framePadding),
            child: SizedBox(
              width: imageWidth,
              height: imageHeight,
              child: ClipRect(child: child),
            ),
          ),
          // Caption area
          if (caption != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: framePadding),
                  child: Text(
                    caption!,
                    style: captionStyle ??
                        const TextStyle(
                          fontFamily: 'serif',
                          fontSize: 14,
                          color: Color(0xFF333333),
                        ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            )
          else
            SizedBox(height: bottomPadding - framePadding),
        ],
      ),
    );

    // Apply rotation if needed
    if (rotation != 0) {
      frame = Transform.rotate(angle: rotation, child: frame);
    }

    return frame;
  }
}
