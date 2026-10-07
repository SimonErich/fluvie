import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Writes one already captured output picture as a PNG without a video decoder.
Future<void> writeNativePoster({
  required File frames,
  required File output,
  required int frame,
  required int width,
  required int height,
}) async {
  final bytesPerFrame = width * height * 4;
  final stream = await frames.open();
  final List<int> pixels;
  try {
    await stream.setPosition(frame * bytesPerFrame);
    pixels = await stream.read(bytesPerFrame);
  } finally {
    await stream.close();
  }
  if (pixels.length != bytesPerFrame) throw StateError('The captured poster frame is truncated.');
  final ready = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels is Uint8List ? pixels : Uint8List.fromList(pixels),
    width,
    height,
    ui.PixelFormat.rgba8888,
    ready.complete,
  );
  final image = await ready.future;
  try {
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    if (png == null) throw StateError('Flutter could not encode the captured poster.');
    await output.writeAsBytes(png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes));
  } finally {
    image.dispose();
  }
}
