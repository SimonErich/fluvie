// Task 25: on the VM (and anywhere without WebCodecs) createWebClipDecoder
// resolves to the fail-on-use stub, so the symbol stays importable for tests and
// analysis while real decoding is browser-only. The live WebCodecs bridge is
// covered by the manual clip-tagged browser harness.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_web_encoder/src/clip_decoder.dart';

void main() {
  test('createWebClipDecoder on the VM fails on use with a clear error', () async {
    final decoder = createWebClipDecoder();

    await expectLater(
      () => decoder.probe(Uint8List(0)),
      throwsA(isA<UnsupportedError>()),
    );
    await expectLater(
      () => decoder.extractFrames(Uint8List(0), const [0], width: 2, height: 2),
      throwsA(isA<UnsupportedError>()),
    );
  });
}
