/// @docImport 'package:fluvie/src/elements/snapshot/device_frame.dart';
library;

import 'dart:ui' show Canvas, Color, Offset, Paint, RRect, Radius, Rect, Size;

import 'package:flutter/rendering.dart' show CustomPainter;

/// Which device chrome a `DeviceFrame` paints: a phone bezel, a browser window
/// with an address bar, or a tablet bezel.
enum DeviceFrameStyle {
  /// A rounded phone bezel with an optional top notch.
  phone,

  /// A browser window with a top address bar carrying traffic-light dots and an
  /// optional url.
  browser,

  /// A thinner rounded tablet bezel (no notch, no address bar).
  tablet,
}

/// Paints the pure presentational chrome of a `DeviceFrame` around its content
/// rect — mirrors `TerminalPainter`: it receives an already-resolved model (the
/// [style], the chrome colors, whether to draw a [notch] / an address bar, and
/// the [url]) and draws only that.
///
/// Capture-safe: every fill is opaque or carries its own alpha, so there is no
/// `saveLayer` and no `BackdropFilter`; the painter draws behind the content
/// child so the framed widget composites over the bezel. [shouldRepaint] is true
/// exactly when a chrome input differs (frame-correct, never time-based).
final class DeviceFramePainter extends CustomPainter {
  /// Creates a painter over the resolved chrome model.
  const DeviceFramePainter({
    required this.style,
    required this.bezelColor,
    required this.chromeColor,
    required this.urlColor,
    required this.notch,
    required this.showAddressBar,
    required this.url,
  });

  /// Which device chrome to paint.
  final DeviceFrameStyle style;

  /// The bezel / window-body color filling the outer frame.
  final Color bezelColor;

  /// The chrome color of the phone notch and the browser address bar.
  final Color chromeColor;

  /// The color the address-bar url text and the bar pill paint in.
  final Color urlColor;

  /// Whether a phone notch is drawn at the top center.
  final bool notch;

  /// Whether a browser address bar is drawn across the top.
  final bool showAddressBar;

  /// The url shown in the address bar, or `null` for an empty bar.
  final String? url;

  /// The three macOS-style traffic-light dots a browser bar draws (a fixed
  /// standard, matching `TerminalPainter`'s dots, not a theme token).
  static const List<Color> _dotColors = [
    Color(0xFFFF5F56),
    Color(0xFFFFBD2E),
    Color(0xFF27C93F),
  ];

  static const double _dotRadius = 4;
  static const double _dotGap = 8;
  static const double _barPad = 12;

  /// The number of traffic-light dots a browser bar paints (`0` otherwise) — a
  /// content probe for tests, never time-based.
  int get dotCount => showAddressBar ? _dotColors.length : 0;

  /// The outer corner radius of the bezel for [style].
  double get cornerRadius => switch (style) {
    DeviceFrameStyle.phone => 28,
    DeviceFrameStyle.browser => 12,
    DeviceFrameStyle.tablet => 20,
  };

  /// The bezel thickness (logical px) for [style]: a phone is the thickest, a
  /// tablet thinner, a browser body has no side bezel.
  double get bezelThickness => switch (style) {
    DeviceFrameStyle.phone => 12,
    DeviceFrameStyle.browser => 0,
    DeviceFrameStyle.tablet => 8,
  };

  /// The address-bar height for a browser style; `0` otherwise.
  double get addressBarHeight => showAddressBar ? 28 : 0;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(cornerRadius),
    );
    canvas.drawRRect(outer, Paint()..color = bezelColor);
    switch (style) {
      case DeviceFrameStyle.phone:
        if (notch) _paintNotch(canvas, size);
      case DeviceFrameStyle.browser:
        if (showAddressBar) _paintAddressBar(canvas, size);
      case DeviceFrameStyle.tablet:
        break;
    }
  }

  void _paintNotch(Canvas canvas, Size size) {
    final width = size.width * 0.4;
    final left = (size.width - width) / 2;
    final notchRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(left, 0, width, bezelThickness + 6),
      bottomLeft: const Radius.circular(8),
      bottomRight: const Radius.circular(8),
    );
    canvas.drawRRect(notchRect, Paint()..color = chromeColor);
  }

  void _paintAddressBar(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, addressBarHeight),
      Paint()..color = chromeColor,
    );
    final cy = addressBarHeight / 2;
    for (var i = 0; i < _dotColors.length; i++) {
      final cx = _barPad + _dotRadius + i * (_dotRadius * 2 + _dotGap);
      canvas.drawCircle(Offset(cx, cy), _dotRadius, Paint()..color = _dotColors[i]);
    }
    final pillLeft = _barPad + _dotColors.length * (_dotRadius * 2 + _dotGap) + _barPad;
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(pillLeft, cy - 8, (size.width - pillLeft - _barPad).clamp(0, size.width), 16),
      const Radius.circular(8),
    );
    canvas.drawRRect(pillRect, Paint()..color = urlColor.withValues(alpha: 0.16));
  }

  @override
  bool shouldRepaint(covariant DeviceFramePainter oldDelegate) =>
      oldDelegate.style != style ||
      oldDelegate.bezelColor != bezelColor ||
      oldDelegate.chromeColor != chromeColor ||
      oldDelegate.urlColor != urlColor ||
      oldDelegate.notch != notch ||
      oldDelegate.showAddressBar != showAddressBar ||
      oldDelegate.url != url;
}
