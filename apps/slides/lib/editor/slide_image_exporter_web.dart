// Browser-only glue: exercised by hand and compiled by the web_build CI
// job; tests inject fakes through the seam in `slide_image_exporter.dart`.
// coverage:ignore-file
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:slides/editor/slide_image_exporter.dart';
import 'package:web/web.dart' as web;

/// The web exporter: one numbered PNG download per slide (browsers expose
/// no folders, so the downloads folder is the honest target).
SlideImageExporter platformSlideImageExporter() => _WebSlideImageExporter();

final class _WebSlideImageExporter implements SlideImageExporter {
  @override
  Future<String?> saveImages({required String baseName, required List<Uint8List> images}) async {
    for (var slide = 0; slide < images.length; slide++) {
      _download(slideImageFileName(baseName, slide, images.length), images[slide]);
    }
    return 'your downloads';
  }

  void _download(String name, Uint8List bytes) {
    final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: 'image/png'));
    final url = web.URL.createObjectURL(blob);
    (web.document.createElement('a') as web.HTMLAnchorElement)
      ..href = url
      ..download = name
      ..click();
    web.URL.revokeObjectURL(url);
  }
}
