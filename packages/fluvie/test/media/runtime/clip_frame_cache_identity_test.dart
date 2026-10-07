import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/media/runtime/clip_frame_cache.dart';

void main() {
  test(
    'identical source pixels decoded by different builds cannot share a persisted frame key',
    () {
      final cache = ClipFrameCache(Directory('/unused'));
      final first = cache.clipKey(
        contentHash: 'same-source',
        width: 8,
        height: 4,
        decoder: 'libvpx-vp9',
        extractionIdentity: 'ffmpeg-build-a',
      );
      final second = cache.clipKey(
        contentHash: 'same-source',
        width: 8,
        height: 4,
        decoder: 'libvpx-vp9',
        extractionIdentity: 'ffmpeg-build-b',
      );
      expect(second, isNot(first));
      expect(first, matches(RegExp(r'^[0-9a-f]{16}$')));
    },
  );
}
