/// Base class for video effects applied during encoding.
///
/// Subclasses define specific visual filters that will be translated
/// to FFmpeg filter expressions.
///
/// **Note:** This is currently a placeholder for future implementation.
/// Video effects are not yet functional and are not exported from the
/// main library.
///
/// Planned effects include:
/// - Vintage/sepia color grading
/// - Blur and sharpen filters
/// - Color adjustments (brightness, contrast, saturation)
/// - Vignette effects
///
/// These will be implemented as FFmpeg filter mappings in a future release.
abstract class VideoEffect {
  /// Returns the FFmpeg filter expression for this effect.
  ///
  /// This will be included in the filter graph during video encoding.
  String toFilterExpression() {
    throw UnimplementedError('VideoEffect is not yet implemented');
  }
}

/// A vintage/sepia color effect.
///
/// **Note:** Not yet implemented.
class VintageEffect implements VideoEffect {
  /// The intensity of the vintage effect (0.0 to 1.0).
  final double intensity;

  const VintageEffect({this.intensity = 1.0});

  @override
  String toFilterExpression() {
    throw UnimplementedError('VintageEffect is not yet implemented');
  }
}
