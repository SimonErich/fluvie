// coverage:ignore-file: drives the real Flutter engine (a live RenderView, manual
// pipeline flushes, and toImage read-back) which only runs in a browser, not the
// unit-test binding; the renderer logic is covered with a tester-backed host.
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:fluvie_web_encoder/src/web_capture_host.dart';

/// Renders a Fluvie capture shell into its own off-screen pipeline sized to the
/// render resolution, so a web app can render a video without the tree ever
/// flickering on screen.
///
/// It owns a standalone [RenderView] + [PipelineOwner] + [BuildOwner] the engine
/// never composites; the capture boundary's `toImage(pixelRatio: 1.0)` reads back
/// exactly [size] pixels. Verified to work on Flutter web's CanvasKit renderer.
final class OffscreenWebCaptureHost implements WebCaptureHost {
  /// Creates a host that renders at [size] logical pixels, using [view] for the
  /// engine handle (defaults to the application's implicit view).
  OffscreenWebCaptureHost(this.size, {ui.FlutterView? view})
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
    await Future<void>.delayed(Duration.zero);
  }
}
