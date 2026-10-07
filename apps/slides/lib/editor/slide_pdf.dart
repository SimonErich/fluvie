import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// One PDF from the slides' settled states: [images] (PNG bytes, slide
/// order) embed one per page, and every page is the deck's canvas —
/// [width] x [height] pixels read as 96 DPI, so a 1920x1080 deck prints as
/// a 20x11.25 inch landscape page. Pure byte generation (the `pdf`
/// package), so the same builder runs on desktop and the web.
Future<Uint8List> buildSlidePdf({
  required List<Uint8List> images,
  required double width,
  required double height,
}) {
  const pointsPerPixel = PdfPageFormat.inch / 96;
  final format = PdfPageFormat(width * pointsPerPixel, height * pointsPerPixel);
  final document = pw.Document();
  for (final png in images) {
    final image = pw.MemoryImage(png);
    document.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.zero,
        build: (context) => pw.Image(image, fit: pw.BoxFit.fill),
      ),
    );
  }
  return document.save();
}
