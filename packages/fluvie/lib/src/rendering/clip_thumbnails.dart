import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/core/media/media_source.dart';

/// Samples real source frames through the same decoder used by live preview.
/// Each PNG has bounded dimensions; the resolver retains ownership of decoded
/// originals. Frames are requested individually to respect bounded clip caches.
Future<List<Uint8List>> clipThumbnails({
  required MediaResolver resolver,
  required MediaSource source,
  int count = 8,
  int width = 96,
  int height = 64,
}) async {
  if (count < 1 || width < 1 || height < 1) {
    throw ArgumentError('Positive thumbnail dimensions/count required');
  }
  final meta = await resolver.probeClip(source);
  if (meta.frameCount < 1) throw StateError('The clip has no frames');
  final result = <Uint8List>[];
  for (var i = 0; i < count; i++) {
    final frame = count == 1 ? 0 : (i * (meta.frameCount - 1) / (count - 1)).round();
    await resolver.preResolveClip(source, [frame]);
    final image = resolver.decodedClipFrame(source, frame);
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint(),
    );
    final picture = recorder.endRecording();
    final thumbnail = await picture.toImage(width, height);
    picture.dispose();
    try {
      final bytes = await thumbnail.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('Could not encode clip thumbnail');
      result.add(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
    } finally {
      thumbnail.dispose();
    }
  }
  return result;
}
