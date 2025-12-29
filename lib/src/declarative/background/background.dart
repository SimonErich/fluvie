import 'package:flutter/widgets.dart';
import '../../presentation/fade_container.dart';
import '../../presentation/time_consumer.dart';
import 'noise_background.dart';
import 'vhs_background.dart';

/// A background for scenes in a video composition.
///
/// [Background] provides various background types including solid colors,
/// gradients, images, videos, and effects like noise and VHS.
///
/// Example:
/// ```dart
/// Scene(
///   background: Background.solid(Colors.blue),
///   children: [...],
/// )
///
/// Scene(
///   background: Background.gradient(
///     colors: {0: Colors.red, 60: Colors.blue},
///   ),
///   children: [...],
/// )
///
/// Scene(
///   background: Background.noise(intensity: 0.05),
///   children: [...],
/// )
/// ```
abstract class Background {
  const Background();

  /// Builds the background widget.
  Widget build(BuildContext context, int sceneLength);

  /// Creates a solid color background.
  const factory Background.solid(Color color) = SolidBackground;

  /// Creates an animated gradient background.
  ///
  /// The [colors] map specifies keyframes where the key is the frame number
  /// and the value is the color at that frame.
  factory Background.gradient({
    required Map<int, Color> colors,
    GradientType type,
    AlignmentGeometry begin,
    AlignmentGeometry end,
  }) = GradientBackground;

  /// Creates an image background.
  const factory Background.image({required String assetPath, BoxFit fit}) =
      ImageBackground;

  /// Creates a video background.
  const factory Background.video({required String assetPath, BoxFit fit}) =
      VideoBackground;

  /// Creates a noise/grain overlay background.
  ///
  /// Adds a film grain or static noise effect that creates texture
  /// and visual interest. Perfect for retro or artistic effects.
  const factory Background.noise({
    double intensity,
    Color color,
    int seed,
    bool animate,
    int animationSpeed,
  }) = NoiseBackground;

  /// Creates a VHS/retro video effect background.
  ///
  /// Adds scanlines, chromatic aberration, tracking distortion,
  /// and noise for a nostalgic VHS tape aesthetic.
  const factory Background.vhs({
    Color baseColor,
    double intensity,
    bool showScanlines,
    bool showChromatic,
    bool animate,
    bool showTracking,
    int seed,
  }) = VHSBackground;

  /// Creates a dark overlay background for improved text readability.
  ///
  /// This is commonly used when overlaying text on images or videos.
  /// The [opacity] controls how dark the overlay is (0.0 to 1.0).
  ///
  /// Example:
  /// ```dart
  /// Scene(
  ///   background: Background.darkOverlay(opacity: 0.5),
  ///   children: [VCenter(child: Text('Readable text'))],
  /// )
  /// ```
  factory Background.darkOverlay({double opacity = 0.4}) {
    return SolidBackground(Color.fromRGBO(0, 0, 0, opacity));
  }

  /// Creates a cinema-style black gradient background.
  ///
  /// Provides a subtle gradient from pure black to very dark gray,
  /// giving a cinematic letterbox feel.
  ///
  /// Example:
  /// ```dart
  /// Scene(
  ///   background: Background.cinemaBlack(),
  ///   children: [...],
  /// )
  /// ```
  factory Background.cinemaBlack() {
    return GradientBackground(
      colors: {0: const Color(0xFF000000)},
      type: GradientType.linear,
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
  }

  /// Creates a radial gradient background with glow effect.
  ///
  /// The gradient radiates from [center] with [centerColor] fading
  /// to [edgeColor] at the edges.
  ///
  /// Example:
  /// ```dart
  /// Scene(
  ///   background: Background.radial(
  ///     centerColor: Colors.purple,
  ///     edgeColor: Colors.black,
  ///   ),
  ///   children: [...],
  /// )
  /// ```
  factory Background.radial({
    required Color centerColor,
    required Color edgeColor,
    Alignment center = Alignment.center,
  }) {
    return RadialBackground(
      centerColor: centerColor,
      edgeColor: edgeColor,
      center: center,
    );
  }
}

/// Type of gradient.
enum GradientType { linear, radial, sweep }

/// A solid color background.
class SolidBackground extends Background {
  final Color color;

  const SolidBackground(this.color);

  @override
  Widget build(BuildContext context, int sceneLength) {
    return FadeContainer(color: color);
  }
}

/// An animated gradient background.
class GradientBackground extends Background {
  /// Keyframe colors: frame -> color.
  final Map<int, Color> colors;

  /// The type of gradient.
  final GradientType type;

  /// Start alignment for linear gradient.
  final AlignmentGeometry begin;

  /// End alignment for linear gradient.
  final AlignmentGeometry end;

  GradientBackground({
    required this.colors,
    this.type = GradientType.linear,
    this.begin = Alignment.topCenter,
    this.end = Alignment.bottomCenter,
  });

  @override
  Widget build(BuildContext context, int sceneLength) {
    if (colors.isEmpty) {
      return const SizedBox.expand();
    }

    // If only one color, return solid
    if (colors.length == 1) {
      return FadeContainer(color: colors.values.first);
    }

    // Sort keyframes
    final sortedFrames = colors.keys.toList()..sort();

    return TimeConsumer(
      builder: (context, frame, progress) {
        final color = _interpolateColor(frame, sortedFrames);
        return _buildGradient(color);
      },
    );
  }

  Color _interpolateColor(int frame, List<int> sortedFrames) {
    // Before first keyframe
    if (frame <= sortedFrames.first) {
      return colors[sortedFrames.first]!;
    }

    // After last keyframe
    if (frame >= sortedFrames.last) {
      return colors[sortedFrames.last]!;
    }

    // Find surrounding keyframes
    int lowerFrame = sortedFrames.first;
    int upperFrame = sortedFrames.last;

    for (int i = 0; i < sortedFrames.length - 1; i++) {
      if (frame >= sortedFrames[i] && frame <= sortedFrames[i + 1]) {
        lowerFrame = sortedFrames[i];
        upperFrame = sortedFrames[i + 1];
        break;
      }
    }

    // Interpolate
    final t = (frame - lowerFrame) / (upperFrame - lowerFrame);
    return Color.lerp(colors[lowerFrame], colors[upperFrame], t)!;
  }

  Widget _buildGradient(Color color) {
    // For a single interpolated color, we can create a simple gradient
    // by using the same color or slightly varying it
    switch (type) {
      case GradientType.linear:
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: begin,
              end: end,
              colors: [color, color.withValues(alpha: 0.8)],
            ),
          ),
        );
      case GradientType.radial:
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0.6)],
            ),
          ),
        );
      case GradientType.sweep:
        return Container(
          decoration: BoxDecoration(
            gradient: SweepGradient(
              colors: [color, color.withValues(alpha: 0.8), color],
            ),
          ),
        );
    }
  }
}

/// An image background.
class ImageBackground extends Background {
  /// Path to the image asset.
  final String assetPath;

  /// How the image should fit.
  final BoxFit fit;

  const ImageBackground({required this.assetPath, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context, int sceneLength) {
    return Image.asset(
      assetPath,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
    );
  }
}

/// A video background.
class VideoBackground extends Background {
  /// Path to the video asset.
  final String assetPath;

  /// How the video should fit.
  final BoxFit fit;

  const VideoBackground({required this.assetPath, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context, int sceneLength) {
    // Video playback would be handled by a video player widget
    // For now, return a placeholder
    return Container(
      color: const Color(0xFF000000),
      child: const Center(
        child: Text(
          'Video Background',
          style: TextStyle(color: Color(0xFFFFFFFF)),
        ),
      ),
    );
  }
}

/// A radial gradient background with customizable center and edge colors.
class RadialBackground extends Background {
  /// The color at the center of the gradient.
  final Color centerColor;

  /// The color at the edges of the gradient.
  final Color edgeColor;

  /// The center point of the gradient.
  final Alignment center;

  const RadialBackground({
    required this.centerColor,
    required this.edgeColor,
    this.center = Alignment.center,
  });

  @override
  Widget build(BuildContext context, int sceneLength) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: center,
          colors: [centerColor, edgeColor],
        ),
      ),
    );
  }
}
