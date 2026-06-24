import 'dart:typed_data';

import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:test/test.dart';

void main() {
  group('TextImage', () {
    test('defaults the mime type to image/png', () {
      final image = TextImage(bytes: Uint8List.fromList(const [1, 2, 3]));
      expect(image.mimeType, 'image/png');
      expect(image.bytes, [1, 2, 3]);
    });

    test('accepts a custom mime type', () {
      final image = TextImage(
        bytes: Uint8List.fromList(const [9]),
        mimeType: 'image/jpeg',
      );
      expect(image.mimeType, 'image/jpeg');
    });
  });
}
