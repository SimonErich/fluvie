import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

// obers_ui upstream candidate: a pan/zoom viewport with a programmatic
// controller (OiPinchZoom is gesture-only).

/// The camera over an editing canvas: a scale and an offset with the
/// screen-to-canvas math the whole editor shares.
///
/// The transform is `viewport = canvas × scale + offset`. Everything that
/// needs to cross the boundary — hit-testing, selection chrome, zoom
/// commands — goes through [toCanvas]/[toViewport], so there is exactly one
/// mapping to get right.
final class CanvasViewportController extends ChangeNotifier {
  /// Creates the camera, clamping zoom to [minScale]..[maxScale].
  CanvasViewportController({this.minScale = 0.1, this.maxScale = 8});

  /// The smallest allowed zoom.
  final double minScale;

  /// The largest allowed zoom.
  final double maxScale;

  double _scale = 1;
  Offset _offset = Offset.zero;

  /// The current zoom level (1 = canvas pixels are screen pixels).
  double get scale => _scale;

  /// Where the canvas origin sits in viewport coordinates.
  Offset get offset => _offset;

  /// The canvas point under [viewportPoint].
  Offset toCanvas(Offset viewportPoint) => (viewportPoint - _offset) / _scale;

  /// The viewport point over [canvasPoint].
  Offset toViewport(Offset canvasPoint) => canvasPoint * _scale + _offset;

  /// Zooms to [scale], keeping [focalInViewport] (or the current origin)
  /// over the same canvas point.
  void zoomTo(double scale, {Offset? focalInViewport}) {
    final clamped = scale.clamp(minScale, maxScale);
    final focal = focalInViewport ?? Offset.zero;
    final anchor = toCanvas(focal);
    _scale = clamped;
    _offset = focal - anchor * _scale;
    notifyListeners();
  }

  /// Pans by [delta] viewport pixels.
  void panBy(Offset delta) {
    _offset += delta;
    notifyListeners();
  }

  /// Fits [canvasSize] into [viewportSize], centered, with [margin] pixels
  /// of breathing room on every side.
  void fit(Size canvasSize, Size viewportSize, {double margin = 32}) {
    zoomToRect(Offset.zero & canvasSize, viewportSize, margin: margin);
  }

  /// Frames [rect] (in canvas coordinates) inside [viewportSize].
  void zoomToRect(Rect rect, Size viewportSize, {double margin = 32}) {
    final available = Size(viewportSize.width - 2 * margin, viewportSize.height - 2 * margin);
    final scale =
        (available.width / rect.width < available.height / rect.height
                ? available.width / rect.width
                : available.height / rect.height)
            .clamp(minScale, maxScale);
    _scale = scale;
    _offset = viewportSize.center(Offset.zero) - rect.center * scale;
    notifyListeners();
  }
}

/// The zoomable, pannable stage a canvas editor works on: mounts [child] at
/// [canvasSize] under [controller]'s camera, and feeds it scroll-wheel zoom
/// (toward the pointer) and drag panning.
final class CanvasViewport extends StatelessWidget {
  /// Shows [child] (the canvas, laid out at [canvasSize]) under the camera.
  const CanvasViewport({
    required this.controller,
    required this.canvasSize,
    required this.child,
    super.key,
  });

  /// The camera; own it outside so commands can drive it.
  final CanvasViewportController controller;

  /// The canvas's logical pixel size.
  final Size canvasSize;

  /// The canvas content.
  final Widget child;

  void _onScroll(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final factor = event.scrollDelta.dy < 0 ? 1.1 : 1 / 1.1;
    controller.zoomTo(controller.scale * factor, focalInViewport: event.localPosition);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerSignal: _onScroll,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (details) => controller.panBy(details.delta),
      child: ClipRect(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => Stack(
            children: [
              // The stack fills the viewport so empty space pans too.
              const Positioned.fill(child: SizedBox.expand()),
              Positioned(
                left: controller.offset.dx,
                top: controller.offset.dy,
                width: canvasSize.width * controller.scale,
                height: canvasSize.height * controller.scale,
                child: FittedBox(
                  child: SizedBox.fromSize(size: canvasSize, child: child),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
