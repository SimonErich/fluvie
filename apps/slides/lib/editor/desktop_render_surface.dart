import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// An off-screen render pipeline sized to the capture resolution at device
/// pixel ratio 1.0, so the running editor UI never flickers while the
/// capture loop pumps (the same shape as the mobile encoder's off-screen
/// host). The binding's build owner is shared on purpose: the capture
/// service finds its boundary through `GlobalKey.currentContext`, which
/// resolves only against the binding's own owner.
final class DesktopRenderSurface {
  /// Creates a surface with fixed logical pixels.
  DesktopRenderSurface(this.size);

  /// The capture surface size in logical pixels.
  final Size size;

  final PipelineOwner _pipelineOwner = PipelineOwner();
  BuildOwner get _buildOwner => WidgetsBinding.instance.buildOwner!;
  late final RenderView _renderView = RenderView(
    view: WidgetsBinding.instance.platformDispatcher.implicitView!,
    configuration: ViewConfiguration(
      logicalConstraints: BoxConstraints.tight(size),
      physicalConstraints: BoxConstraints.tight(size),
    ),
  );
  RenderObjectToWidgetElement<RenderBox>? _element;

  /// Mounts a capture tree without replacing the editor view.
  Future<void> mount(Widget tree) async {
    _pipelineOwner.rootNode = _renderView;
    _renderView.prepareInitialFrame();
    _element = RenderObjectToWidgetAdapter<RenderBox>(
      container: _renderView,
      child: tree,
    ).attachToRenderTree(_buildOwner);
    await _flush();
    // Video collects registrations on its first build and resolves them in a
    // post-frame callback. A pipeline flush alone never runs that callback;
    // waiting one event-loop turn made frame zero depend on incidental UI vsync.
    // Request the framework frame explicitly (also when the window is hidden),
    // then paint the rebuild scheduled by the completed registration pass.
    final binding = WidgetsBinding.instance;
    final registered = binding.endOfFrame;
    binding.scheduleWarmUpFrame();
    await registered;
    await _flush();
  }

  /// Flushes one explicitly sought capture frame.
  Future<void> pumpFrame() => _flush();

  /// Unmounts the capture subtree before releasing its render pipeline.
  Future<void> dispose() async {
    final element = _element;
    if (element == null) return;
    _element = RenderObjectToWidgetAdapter<RenderBox>(
      container: _renderView,
    ).attachToRenderTree(_buildOwner, element);
    _buildOwner
      ..buildScope(_element!)
      ..finalizeTree();
    _pipelineOwner.rootNode = null;
    _element = null;
    _renderView.dispose();
    _pipelineOwner.dispose();
  }

  Future<void> _flush() async {
    _buildOwner.buildScope(_element!);
    _pipelineOwner
      ..flushLayout()
      ..flushCompositingBits()
      ..flushPaint();
    _buildOwner.finalizeTree();
    // Yield so the painted layers settle before the boundary reads back.
    await Future<void>.delayed(Duration.zero);
  }
}
