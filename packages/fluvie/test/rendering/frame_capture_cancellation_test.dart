import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie/src/rendering/encoding/frame_store.dart';
import 'package:fluvie/src/rendering/frame_capture_loop.dart';

void main() {
  for (final stage in ['lookup', 'capture', 'store', 'consume']) {
    test('cancellation interrupts a blocked $stage without reporting completion', () async {
      final cancellation = RenderCancellation();
      final blocked = _BlockedStage(stage);
      var progress = 0;
      final capture = runFrameCaptureLoop(
        config: RenderConfig(width: 2, height: 2, frameCount: 1),
        digest: 'composition',
        pump: (_) async {},
        boundaryKey: GlobalKey(),
        capture: blocked,
        store: blocked,
        onFrame: (_) => blocked.wait('consume'),
        onProgress: (_, _) => progress++,
        cancellation: cancellation,
      );
      await blocked.started.future;
      final result = expectLater(
        capture.timeout(const Duration(milliseconds: 100)),
        throwsA(isA<RenderCancelledException>()),
      );
      cancellation.cancel();
      await result;
      expect(progress, 0);
    });
  }
}

class _BlockedStage implements FrameCaptureService, FrameStore {
  _BlockedStage(this.stage);
  final String stage;
  final started = Completer<void>();

  Future<void> wait(String candidate) {
    if (candidate != stage) return Future<void>.value();
    started.complete();
    return Completer<void>().future;
  }

  @override
  Future<RawFrame> capture({
    required GlobalKey boundaryKey,
    required int frameIndex,
    required int width,
    required int height,
  }) async {
    await wait('capture');
    return RawFrame(
      frameIndex: frameIndex,
      width: width,
      height: height,
      rgba: Uint8List(width * height * 4),
    );
  }

  @override
  Future<Uint8List?> lookup(String digest, int frameIndex) async {
    await wait('lookup');
    return null;
  }

  @override
  Future<void> store(String digest, int frameIndex, Uint8List bytes) => wait('store');
}
