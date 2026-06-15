@Tags(['snapshot'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/snapshot/snapshot_request.dart';
import 'package:fluvie/src/elements/snapshot/cdp/chrome_snapshot_service.dart';

/// The live Chrome path (decision D-CdpHarness, best-effort/deferred). This test
/// self-skips when no Chrome binary resolves, so the gate never depends on it.
void main() {
  test('resolves a real Chrome binary when one is installed', () {
    final service = ChromeSnapshotService();
    String? binary;
    try {
      binary = service.resolveBinary();
    } on Object {
      binary = null;
    }
    if (binary == null) {
      markTestSkipped('no Chrome binary present; skipping the live snapshot test');
      return;
    }
    expect(File(binary).existsSync(), isTrue);
  });

  test('live capture is deferred until the CDP transport lands', () async {
    final service = ChromeSnapshotService();
    try {
      service.resolveBinary();
    } on Object {
      markTestSkipped('no Chrome binary present; skipping the live snapshot test');
      return;
    }
    // The transport is intentionally not wired yet; capture throws a clear,
    // typed error rather than producing a non-deterministic frame.
    await expectLater(
      () => service.rasterize(const SnapshotRequest.mermaid('graph TD; A-->B')),
      throwsA(isA<Exception>()),
    );
  });
}
