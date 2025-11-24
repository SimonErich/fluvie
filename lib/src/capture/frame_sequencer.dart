import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class FrameSequencer {
  final GlobalKey repaintBoundaryKey;

  FrameSequencer(this.repaintBoundaryKey);

  Future<ui.Image> captureFrame({double pixelRatio = 3.0}) async {
    final RenderRepaintBoundary? boundary = repaintBoundaryKey.currentContext
        ?.findRenderObject() as RenderRepaintBoundary?;

    if (boundary == null) {
      throw Exception('RepaintBoundary not found');
    }

    if (boundary.debugNeedsPaint) {
      // This might happen if the frame hasn't been rasterized yet.
      // In a real isolate loop, we would ensure the frame is built.
      // For now, we assume the widget tree is built.
      // We might need to wait for end of frame.
      await Future.delayed(Duration.zero);
    }

    final image = await boundary.toImage(pixelRatio: pixelRatio);
    return image;
  }
}
