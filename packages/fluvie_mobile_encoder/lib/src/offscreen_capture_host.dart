// coverage:ignore-file: drives the real Flutter engine (a live RenderView, manual
// pipeline flushes, and toImage read-back) which runs only in a hosted app or an
// on-device integration test, never under the unit-test binding; the orchestrator
// logic is covered with a tester-backed CaptureHost instead.
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:fluvie_mobile_encoder/src/capture_host.dart';

/// The production [CaptureHost]: renders the capture shell into its own
/// off-screen pipeline sized to the target resolution.
///
/// It owns a standalone [RenderView] + [PipelineOwner] + [BuildOwner] that the
/// engine never composites to the screen, so an app can render a video while its
/// real UI stays put. The view is configured to [size] logical pixels at device
/// pixel ratio 1.0, so the capture boundary's `toImage(pixelRatio: 1.0)` reads
/// back exactly `size.width` by `size.height` pixels — the dimension contract
/// Fluvie's capture asserts.
final class OffscreenCaptureHost implements CaptureHost {
  /// Creates a host that renders at [size] logical pixels, using [view] for the
  /// engine handle (defaults to the application's implicit view).
  OffscreenCaptureHost(this.size, {ui.FlutterView? view})
    : _view = view ?? WidgetsBinding.instance.platformDispatcher.implicitView!;

  /// The off-screen surface size in logical pixels.
  final Size size;

  final ui.FlutterView _view;
  final PipelineOwner _pipelineOwner = PipelineOwner();
  final BuildOwner _buildOwner = BuildOwner(focusManager: FocusManager());
  late final RenderView _renderView = RenderView(
    view: _view,
    configuration: ViewConfiguration(
      logicalConstraints: BoxConstraints.tight(size),
      physicalConstraints: BoxConstraints.tight(size),
    ),
  );
  RenderObjectToWidgetElement<RenderBox>? _element;

  @override
  Future<void> mount(Widget tree) async {
    _pipelineOwner.rootNode = _renderView;
    _renderView.prepareInitialFrame();
    _element = RenderObjectToWidgetAdapter<RenderBox>(
      container: _renderView,
      child: tree,
    ).attachToRenderTree(_buildOwner);
    await _flush();
  }

  @override
  Future<void> pumpFrame() => _flush();

  @override
  Future<void> dispose() async {
    _pipelineOwner.rootNode = null;
    _element = null;
  }

  Future<void> _flush() async {
    _buildOwner.buildScope(_element!);
    _pipelineOwner
      ..flushLayout()
      ..flushCompositingBits()
      ..flushPaint();
    _buildOwner.finalizeTree();
    // Yield so the just-painted layers settle before the boundary is read back.
    await Future<void>.delayed(Duration.zero);
  }
}
