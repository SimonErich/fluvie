import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:fluvie_web_encoder/fluvie_web_encoder.dart';
import 'package:slides/editor/media_metadata.dart';
import 'package:web/web.dart' as web;

Future<MediaMetadata> probeImportedMedia({
  required String? path,
  required Uint8List? bytes,
  required bool video,
  required bool audio,
}) async {
  if (bytes == null) return const MediaMetadata();
  try {
    if (video) {
      final info = await createWebClipDecoder().probe(bytes).timeout(const Duration(seconds: 20));
      return MediaMetadata(
        duration: '${info.frameCount / info.fps}s',
        width: info.width,
        height: info.height,
        fps: info.fps,
      );
    }
    if (audio) {
      final url = web.URL.createObjectURL(web.Blob([bytes.toJS].toJS));
      final element = web.HTMLAudioElement()..preload = 'metadata';
      final ready = Completer<void>();
      element
        ..onloadedmetadata = ((web.Event _) {
          if (!ready.isCompleted) ready.complete();
        }).toJS
        ..onerror = ((web.Event _) {
          if (!ready.isCompleted) ready.completeError(StateError('Audio metadata unavailable'));
        }).toJS;
      try {
        element.src = url;
        await ready.future.timeout(const Duration(seconds: 20));
        final seconds = element.duration;
        return seconds.isFinite && seconds > 0
            ? MediaMetadata(duration: '${seconds}s', fps: 1000)
            : const MediaMetadata();
      } finally {
        element
          ..removeAttribute('src')
          ..load();
        web.URL.revokeObjectURL(url);
      }
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        return MediaMetadata(width: descriptor.width, height: descriptor.height);
      } finally {
        descriptor.dispose();
      }
    } finally {
      buffer.dispose();
    }
  } on Object {
    return const MediaMetadata();
  }
}
