import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Encodes one captured frame's raw RGBA8888 [rgba] (`width * height * 4` bytes,
/// straight from `Image.toByteData()`) to PNG bytes via the engine's image codec.
///
/// This is the browser render path's `FrameEncoder`: `renderToSandbox` calls it
/// per frame so each frame becomes its own small PNG file. That keeps peak memory
/// bounded to a single frame at a time, instead of accumulating every raw frame
/// into one multi-gigabyte buffer that overflows the browser/wasm heap — the
/// cause of the long-render hang this replaces.
Future<Uint8List> encodeFramePng(Uint8List rgba, int width, int height) async {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    rgba,
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  final image = await completer.future;
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw StateError('PNG encoding returned no data for a ${width}x$height frame.');
    }
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image.dispose();
  }
}
