// WI-22 (decision D16): the committed media fixtures lessons 05/06 and the
// element goldens rely on. Both must be real, bundle-loadable files so the
// lessons render offline and the network path is never touched in tests.

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('media fixtures are committed and bundle-loadable (WI-22)', () {
    test('swatch.png loads from the asset bundle with bytes', () async {
      final data = await rootBundle.load('assets/fixtures/swatch.png');
      expect(data.lengthInBytes, greaterThan(0));
      // The PNG magic number proves it is a real image, not a placeholder.
      final header = data.buffer.asUint8List(data.offsetInBytes, 8);
      expect(header, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    });

    test('clip_1s.mp4 loads from the asset bundle with bytes', () async {
      final data = await rootBundle.load('assets/fixtures/clip_1s.mp4');
      expect(data.lengthInBytes, greaterThan(0));
      // The ISO base-media `ftyp` box sits at offset 4 in an MP4.
      final tag = data.buffer.asUint8List(data.offsetInBytes + 4, 4);
      expect(String.fromCharCodes(tag), 'ftyp');
    });
  });
}
