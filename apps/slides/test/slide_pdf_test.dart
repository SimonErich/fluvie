import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:slides/editor/slide_pdf.dart';

/// A 1x1 PNG, the smallest real image the PDF embedder can measure.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

void main() {
  test('builds one page per slide at the deck size in points', () async {
    final bytes = await buildSlidePdf(images: [_png, _png, _png], width: 320, height: 180);
    final text = latin1.decode(bytes);
    // A real PDF leads with its magic and counts its pages honestly.
    expect(text.startsWith('%PDF'), isTrue);
    expect(RegExp(r'/Count (\d+)').firstMatch(text)?.group(1), '3');
    // 320x180 px at 96 DPI is 240x135 PDF points.
    expect(text, contains('/MediaBox'));
    expect(text, contains('240'));
    expect(text, contains('135'));
  });

  test('a single slide makes a single-page PDF', () async {
    final bytes = await buildSlidePdf(images: [_png], width: 320, height: 180);
    final text = latin1.decode(bytes);
    expect(RegExp(r'/Count (\d+)').firstMatch(text)?.group(1), '1');
  });
}
