import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart' show collectMediaSources;
import 'package:fluvie_ai/fluvie_ai.dart';

/// Rejects host-file and off-allowlist network sources on the untrusted render
/// path, mirroring the main loop's `MediaBytesLoader` block.
///
/// The poster grounds a conversational edit: its pixels are uploaded to a
/// multimodal model. In preview mode a `FileSource` reads a host file and a
/// `NetworkSource` fetches an arbitrary URL with no allowlist, so an untrusted
/// base spec could exfiltrate a local file (or probe an internal URL) through
/// that grounding image. When [block] is set (the pipeline sets
/// `FLUVIE_BLOCK_FILE_SOURCES` for every non-key render) reject those sources
/// before the poster paints, exactly as the frame loop does. Trusted key
/// renders leave [block] off and read normally.
void assertPosterSourcesAllowed(Iterable<MediaSource> sources, {required bool block}) {
  if (!block) return;
  for (final source in sources) {
    if (source is FileSource || source is NetworkSource) {
      throw FluvieRenderException(
        'A ${source.runtimeType} in the base spec cannot ground an untrusted '
        'edit poster: reading local files or off-allowlist URLs is disabled here.',
      );
    }
  }
}

/// Renders a representative frame of [spec] to a PNG and returns it as an
/// [AiImage] — the visual grounding fed back to a multimodal model for a
/// conversational refinement.
///
/// Mounts the built video at its declared size (device pixel ratio 1.0) under a
/// [RepaintBoundary] in preview mode, seeks to a mid frame (past the enter
/// animations), and reads the boundary back as PNG bytes. Runs the readback in
/// `tester.runAsync` because `toImage` needs a real event loop.
Future<AiImage> renderPosterPng({required WidgetTester tester, required VideoSpec spec}) async {
  final video = spec.build();
  // The base spec is untrusted on an edit; block file and network sources on the
  // hardened path before they reach the preview fallback and the model.
  assertPosterSourcesAllowed(
    collectMediaSources(video.scenes),
    block: const bool.fromEnvironment('FLUVIE_BLOCK_FILE_SOURCES'),
  );
  final width = spec.size.width;
  final height = spec.size.height;
  final frame = (video.totalFrames * 0.5).round().clamp(0, video.totalFrames - 1);

  tester.view.physicalSize = ui.Size(width.toDouble(), height.toDouble());
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final controller = RenderController();
  final boundaryKey = GlobalKey();
  await tester.pumpWidget(
    RenderModeContext(
      mode: RenderMode.preview,
      child: RenderControllerScope(
        controller: controller,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            key: boundaryKey,
            child: SizedBox(width: width.toDouble(), height: height.toDouble(), child: video),
          ),
        ),
      ),
    ),
  );
  controller.seek(frame);
  await tester.pump();

  late Uint8List bytes;
  await tester.runAsync(() async {
    final boundary = boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    bytes = data!.buffer.asUint8List();
  });
  return AiImage(bytes: bytes);
}
