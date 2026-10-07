import 'package:flutter/widgets.dart';
import 'package:fluvie/src/animation/effect_kind.dart';

/// The effect behind `kind: "grade"`: exposure, contrast, saturation,
/// temperature and tint composed into a single 4x5 `ColorFilter.matrix` —
/// one filter, one composite, capture-safe by the same discipline the
/// chromatic effect follows (no `BackdropFilter`, no `saveLayer` of its
/// own), and a pure function of its parameters, so every pump paints
/// identical pixels.
///
/// **The composition order is pinned**: white balance (temperature and
/// tint), then exposure, then contrast, then saturation. Matrix
/// multiplication does not commute, and a silent reorder would regrade
/// every document; the order lives in [matrixFor] and its tests, nowhere
/// else.
final class ColorGradeEffect implements PixelAnimationEffect {
  /// Creates a grade; every parameter defaults to its neutral value.
  const ColorGradeEffect({
    this.exposure = 0,
    this.contrast = 1,
    this.saturation = 1,
    this.temperature = 0,
    this.tint = 0,
    this.intensity = 1,
  });

  /// Stops of exposure: each one doubles the colour channels.
  final double exposure;

  /// Contrast around mid grey; one is neutral.
  final double contrast;

  /// Saturation toward Rec. 709 luminance grey at zero; one is neutral.
  final double saturation;

  /// Warmth: positive gains red and cuts blue, negative the reverse.
  final double temperature;

  /// Green–magenta balance: positive is magenta, negative green.
  final double tint;

  /// Mix toward the untouched input; zero is an exact no-op.
  final double intensity;

  /// The composed 4x5 matrix for the given parameters. The neutral grade
  /// composes to exactly the identity, which is what makes a document that
  /// gains an all-default grade block a pixel-for-pixel no-op.
  static List<double> matrixFor({
    double exposure = 0,
    double contrast = 1,
    double saturation = 1,
    double temperature = 0,
    double tint = 0,
  }) {
    // White balance and exposure are diagonal gains, folded directly.
    final gain = _pow2(exposure);
    final r = gain * (1 + 0.2 * temperature);
    final g = gain * (1 - 0.2 * tint);
    final b = gain * (1 - 0.2 * temperature);
    // Contrast scales around mid grey (127.5 in the 0..255 filter space).
    final offset = 127.5 * (1 - contrast);
    final graded = <double>[
      r * contrast, 0, 0, 0, offset, //
      0, g * contrast, 0, 0, offset, //
      0, 0, b * contrast, 0, offset, //
      0, 0, 0, 1, 0, //
    ];
    if (saturation == 1) return graded;
    return _compose(_saturationMatrix(saturation), graded);
  }

  /// 2^[stops] without dart:math, so the identity case is exactly 1.
  static double _pow2(double stops) {
    if (stops == 0) return 1;
    final magnitude = stops.abs();
    var result = 1.0;
    var n = magnitude.floor();
    while (n-- > 0) {
      result *= 2;
    }
    final fraction = magnitude - magnitude.floorToDouble();
    if (fraction > 0) {
      // A short series on ln 2 keeps this dependency-free and exact enough
      // for a gain (the error is far below one 8-bit step).
      const ln2 = 0.6931471805599453;
      final x = fraction * ln2;
      var term = 1.0;
      var sum = 1.0;
      for (var i = 1; i <= 8; i++) {
        term *= x / i;
        sum += term;
      }
      result *= sum;
    }
    return stops < 0 ? 1 / result : result;
  }

  /// The Rec. 709 luminance-weighted saturation matrix.
  static List<double> _saturationMatrix(double s) {
    const lr = 0.2126;
    const lg = 0.7152;
    const lb = 0.0722;
    return <double>[
      lr * (1 - s) + s, lg * (1 - s), lb * (1 - s), 0, 0, //
      lr * (1 - s), lg * (1 - s) + s, lb * (1 - s), 0, 0, //
      lr * (1 - s), lg * (1 - s), lb * (1 - s) + s, 0, 0, //
      0, 0, 0, 1, 0, //
    ];
  }

  /// [after] applied to the result of [before]: the 4x5 product with the
  /// offset column carried through.
  static List<double> _compose(List<double> after, List<double> before) => [
    for (var row = 0; row < 4; row++) ...[
      for (var col = 0; col < 4; col++)
        after[row * 5] * before[col] +
            after[row * 5 + 1] * before[5 + col] +
            after[row * 5 + 2] * before[10 + col] +
            after[row * 5 + 3] * before[15 + col],
      after[row * 5] * before[4] +
          after[row * 5 + 1] * before[9] +
          after[row * 5 + 2] * before[14] +
          after[row * 5 + 3] * before[19] +
          after[row * 5 + 4],
    ],
  ];

  /// Interpolates a grade matrix with identity in output colour space.
  static List<double> mixMatrix(List<double> matrix, double intensity) {
    if (intensity >= 1) return matrix;
    final t = intensity.clamp(0.0, 1.0);
    return [
      for (var i = 0; i < 20; i++)
        (i == 0 || i == 6 || i == 12 || i == 18 ? 1.0 : 0.0) * (1 - t) + matrix[i] * t,
    ];
  }

  @override
  Widget build(Widget child, double progress) => intensity <= 0
      ? child
      : ColorFiltered(
          colorFilter: ColorFilter.matrix(
            mixMatrix(
              matrixFor(
                exposure: exposure,
                contrast: contrast,
                saturation: saturation,
                temperature: temperature,
                tint: tint,
              ),
              intensity,
            ),
          ),
          child: child,
        );

  @override
  String toString() =>
      'ColorGradeEffect(exposure: $exposure, contrast: $contrast, '
      'saturation: $saturation, temperature: $temperature, tint: $tint)';
}
