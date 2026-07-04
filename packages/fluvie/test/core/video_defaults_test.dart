// The named render defaults: one place declares the package's default frame
// rate and canvas long edge, and every render entry point defaults to it.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/defaults.dart';

void main() {
  group('VideoDefaults', () {
    test('fps is 30', () {
      expect(VideoDefaults.fps, 30);
    });

    test('longEdge is 1920', () {
      expect(VideoDefaults.longEdge, 1920);
    });
  });
}
