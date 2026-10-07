import 'dart:ui' as ui;

import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:fluvie_ai/src/client/ai_client.dart';
import 'package:fluvie_ai/src/client/evidence_image_limits.dart';

/// Preserves all selected visual references on providers with a single-image
/// request contract. One image passes through unchanged; up to four become a
/// labeled, letterboxed PNG. Original captions stay in the text conversation.
Future<TextImage?> composeEvidenceImage(List<AiMessage> messages) async {
  final images = messages.map((message) => message.image).whereType<AiImage>().toList();
  if (images.isEmpty) return null;
  checkEvidenceImageLimits(images);
  if (images.length == 1) {
    return TextImage(bytes: images.single.bytes, mimeType: images.single.mediaType);
  }
  const width = 1024;
  const cellHeight = 576;
  const labelHeight = 28;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final decoded = <ui.Image>[];
  ui.Picture? picture;
  ui.Image? composite;
  try {
    for (var index = 0; index < images.length; index++) {
      final buffer = await ui.ImmutableBuffer.fromUint8List(images[index].bytes);
      ui.ImageDescriptor? descriptor;
      ui.Codec? codec;
      try {
        descriptor = await ui.ImageDescriptor.encoded(buffer);
        final scale = (width / descriptor.width).clamp(0, cellHeight / descriptor.height);
        codec = await descriptor.instantiateCodec(
          targetWidth: (descriptor.width * scale).round().clamp(1, width),
          targetHeight: (descriptor.height * scale).round().clamp(1, cellHeight),
        );
        decoded.add((await codec.getNextFrame()).image);
      } finally {
        codec?.dispose();
        descriptor?.dispose();
        buffer.dispose();
      }
      final image = decoded.last;
      final top = index * (cellHeight + labelHeight).toDouble();
      canvas.drawRect(
        ui.Rect.fromLTWH(0, top, width.toDouble(), labelHeight.toDouble()),
        ui.Paint()..color = const ui.Color(0xffffffff),
      );
      final label =
          (ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 18))
                ..pushStyle(ui.TextStyle(color: const ui.Color(0xff000000)))
                ..addText('Evidence ${index + 1}'))
              .build()
            ..layout(const ui.ParagraphConstraints(width: 1024));
      try {
        canvas.drawParagraph(label, ui.Offset(8, top + 2));
      } finally {
        label.dispose();
      }
      canvas.drawImage(
        image,
        ui.Offset((width - image.width) / 2, top + labelHeight + (cellHeight - image.height) / 2),
        ui.Paint(),
      );
    }
    picture = recorder.endRecording();
    composite = await picture.toImage(width, images.length * (cellHeight + labelHeight));
    final png = await composite.toByteData(format: ui.ImageByteFormat.png);
    if (png == null) throw AiClientException('Could not encode visual references.');
    return TextImage(bytes: png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes));
  } catch (error) {
    if (error is AiClientException) rethrow;
    throw AiClientException('Could not prepare visual references: $error');
  } finally {
    composite?.dispose();
    picture?.dispose();
    for (final image in decoded) {
      image.dispose();
    }
    if (recorder.isRecording) recorder.endRecording().dispose();
  }
}
