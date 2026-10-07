import 'dart:math' as math;
import 'dart:typed_data';

import 'package:slides/editor/slide_image_exporter_io.dart'
    if (dart.library.js_interop) 'package:slides/editor/slide_image_exporter_web.dart';

/// Saves one PNG per slide: a folder pick plus numbered files on desktop,
/// numbered downloads on the web.
///
/// A contract (not a typedef) so tests inject a recording fake through the
/// editor screen's seam.
// ignore: one_member_abstracts
abstract interface class SlideImageExporter {
  /// The exporter for the running platform.
  factory SlideImageExporter.platform() => platformSlideImageExporter();

  /// Writes [images] (PNG bytes, slide order) named after [baseName] via
  /// [slideImageFileName]. Returns where they went (a directory path on
  /// desktop, "your downloads" on the web), or null when the user
  /// cancelled the pick.
  Future<String?> saveImages({required String baseName, required List<Uint8List> images});
}

/// The file name of slide [index] (zero-based) in a deck of [count]:
/// `<base>-01.png`, padded to the deck's width (at least two digits).
String slideImageFileName(String baseName, int index, int count) {
  final width = math.max(2, count.toString().length);
  return '$baseName-${(index + 1).toString().padLeft(width, '0')}.png';
}
