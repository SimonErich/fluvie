/// @docImport 'package:fluvie/src/core/time.dart';
library;

import 'dart:math' as math;

import 'package:meta/meta.dart' show immutable;

/// A pure mapping from data values to pixel positions.
///
/// Scales are the chart's data-transform layer: they are computed in a chart's
/// `build` and handed to the painter as resolved geometry, so the painter never
/// does data math (the separation-of-concerns guardrail). They hold no canvas,
/// widget, or frame state — only numbers — and are unit-tested without a
/// painter.
///
/// Two variants ship:
///
/// * [LinearScale] — a continuous value range mapped to a pixel range, used by
///   value (y) axes and the x positions of scatter / line points.
/// * [CategoryScale] — ordered category keys mapped to evenly spaced bands,
///   used by the categorical (x) axis of bar / line / area charts.
///
/// A `TimeScale` (a value axis over [Time]) is not provided yet: the built-in
/// chart examples are categorical and no consumer needs a time axis. Add it
/// when one does.
@immutable
sealed class ChartScale {
  /// Const base constructor shared by both variants.
  const ChartScale();
}

/// Maps a continuous value domain `[domainMin, domainMax]` to a pixel range
/// `[pixelMin, pixelMax]`.
///
/// The pixel range may invert the domain ([pixelMin] > [pixelMax]) to model an
/// upward y axis where a larger value sits at a smaller pixel (higher on
/// screen). [toPixel] clamps values outside the domain into the pixel bounds so
/// stray data never paints off-axis. All math stays finite even when the domain
/// is degenerate (see [LinearScale.niceBounds]).
final class LinearScale extends ChartScale {
  /// Creates a scale mapping `[domainMin, domainMax]` to
  /// `[pixelMin, pixelMax]`.
  const LinearScale({
    required this.domainMin,
    required this.domainMax,
    required this.pixelMin,
    required this.pixelMax,
  });

  /// Builds a scale over human-rounded bounds for the data `[min, max]`.
  ///
  /// Non-negative data keeps `0` as the domain minimum (a zero baseline), and
  /// the maximum rounds up to a "nice" tick (a 1 / 2 / 5 multiple of a power of
  /// ten), so `[0, 87]` becomes `[0, 100]`. Degenerate input — all values
  /// equal, or all zero — widens to a small finite domain rather than a
  /// zero-width one, so no later division produces `NaN`.
  factory LinearScale.niceBounds({
    required num min,
    required num max,
    required double pixelMin,
    required double pixelMax,
  }) {
    final lowRaw = min < 0 ? min.toDouble() : 0.0;
    final highRaw = max > 0 ? max.toDouble() : 0.0;
    if (lowRaw == highRaw) {
      // All-equal (or all-zero) data: widen to a 1-unit window around the value.
      final base = lowRaw == 0 ? 1.0 : lowRaw.abs();
      return LinearScale(
        domainMin: math.min(lowRaw, 0),
        domainMax: lowRaw + base,
        pixelMin: pixelMin,
        pixelMax: pixelMax,
      );
    }
    return LinearScale(
      domainMin: lowRaw < 0 ? _niceFloor(lowRaw) : 0,
      domainMax: _niceCeil(highRaw),
      pixelMin: pixelMin,
      pixelMax: pixelMax,
    );
  }

  /// The smallest data value the scale represents (often a zero baseline).
  final double domainMin;

  /// The largest data value the scale represents.
  final double domainMax;

  /// The pixel position the [domainMin] maps to.
  final double pixelMin;

  /// The pixel position the [domainMax] maps to.
  final double pixelMax;

  /// The pixel where the domain crosses zero, clamped into the pixel range.
  ///
  /// For an upward y axis this is the chart's baseline. When zero falls outside
  /// the domain the value clamps to the nearer bound rather than extrapolating
  /// off-axis.
  double get baselinePixel => toPixel(0);

  /// The pixel position for data [value], clamped into `[pixelMin, pixelMax]`.
  double toPixel(num value) {
    final span = domainMax - domainMin;
    if (span == 0) return pixelMin;
    final t = ((value - domainMin) / span).clamp(0.0, 1.0);
    return pixelMin + (pixelMax - pixelMin) * t;
  }

  /// `count + 1` evenly spaced tick values spanning the domain inclusively.
  ///
  /// A [count] of `4` over `[0, 100]` returns `[0, 25, 50, 75, 100]`; a
  /// non-positive count collapses to the two domain endpoints. The values are
  /// pure arithmetic, so they are identical on every machine and pump.
  List<double> ticks(int count) {
    if (count <= 0) return [domainMin, domainMax];
    return [for (var i = 0; i <= count; i++) domainMin + (domainMax - domainMin) * i / count];
  }

  /// Rounds [value] up to the nearest 1 / 2 / 5 multiple of a power of ten.
  static double _niceCeil(double value) {
    final magnitude = math.pow(10, (math.log(value) / math.ln10).floor()).toDouble();
    for (final step in const [1.0, 2.0, 5.0, 10.0]) {
      final candidate = step * magnitude;
      if (candidate >= value) return candidate;
    }
    return 10 * magnitude;
  }

  /// Rounds a negative [value] down to the nearest nice multiple (mirror of
  /// [_niceCeil]).
  static double _niceFloor(double value) => -_niceCeil(-value);
}

/// Maps ordered category keys to evenly spaced bands across a pixel extent.
///
/// Each category owns one band of width `extent / count`; [centerOf] returns a
/// band's midpoint and [leftEdgeOf] / [rightEdgeOf] its (optionally padded)
/// edges. [padding] is the fraction of the band width removed symmetrically
/// (so a bar fills the remainder), in `[0, 1)`. An empty category list and a
/// single category both stay finite — no division ever yields `NaN`.
final class CategoryScale extends ChartScale {
  /// Creates a scale over [categories] across `[pixelMin, pixelMax]`, with an
  /// optional [padding] fraction inset from each band's edges.
  const CategoryScale({
    required this.categories,
    required this.pixelMin,
    required this.pixelMax,
    this.padding = 0,
  });

  /// The ordered category keys; index order is draw order.
  final List<String> categories;

  /// The first pixel of the band extent.
  final double pixelMin;

  /// The last pixel of the band extent.
  final double pixelMax;

  /// The fraction of each band removed symmetrically as inter-band gap, in
  /// `[0, 1)`; `0` makes bands touch.
  final double padding;

  /// The full (unpadded) width of one band; `0` when there are no categories.
  double get fullBandWidth => categories.isEmpty ? 0 : (pixelMax - pixelMin) / categories.length;

  /// The drawable width of one band after [padding] is removed.
  double get bandWidth => fullBandWidth * (1 - padding);

  /// The center pixel of [category], or `null` when it is not present.
  double? centerOf(String category) {
    final index = categories.indexOf(category);
    if (index < 0) return null;
    return pixelMin + fullBandWidth * (index + 0.5);
  }

  /// The left (padded) edge pixel of [category], or `null` when absent.
  double? leftEdgeOf(String category) {
    final center = centerOf(category);
    return center == null ? null : center - bandWidth / 2;
  }

  /// The right (padded) edge pixel of [category], or `null` when absent.
  double? rightEdgeOf(String category) {
    final center = centerOf(category);
    return center == null ? null : center + bandWidth / 2;
  }
}
