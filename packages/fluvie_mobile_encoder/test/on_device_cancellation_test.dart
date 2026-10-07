import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie_mobile_encoder/fluvie_mobile_encoder.dart';

class _CancellingHost implements CaptureHost {
  _CancellingHost(this.tester, this.cancellation);
  final WidgetTester tester;
  final RenderCancellation cancellation;
  bool disposed = false;
  @override
  Future<void> mount(Widget tree) => tester.pumpWidget(tree);
  @override
  Future<void> pumpFrame() async {
    await tester.pump();
    cancellation.cancel();
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  testWidgets('cancel during preparation tears down and never encodes', (tester) async {
    final dir = Directory.systemTemp.createTempSync('fluvie_cancel_test_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final cancellation = RenderCancellation();
    final encoder = FakeMobileVideoEncoder();
    final host = _CancellingHost(tester, cancellation);
    final renderer = OnDeviceVideoRenderer(
      encoder: encoder,
      cancellation: cancellation,
      hostFactory: (_) => host,
      sandboxFactory: () async => dir,
    );
    Object? failure;
    await tester.runAsync(() async {
      try {
        await renderer.render(
          composition: const SizedBox.shrink(),
          aspect: Aspect.square,
          duration: const Duration(seconds: 1),
          longEdge: 64,
        );
      } on Object catch (error) {
        failure = error;
      }
    });
    expect(failure, isA<RenderCancelledException>());
    expect(encoder.requests, isEmpty);
    expect(host.disposed, isTrue);
    expect(dir.existsSync(), isFalse);
  });
  test('cancelled render does not open a capture host or sandbox', () async {
    final cancellation = RenderCancellation()..cancel();
    var opened = false;
    final renderer = OnDeviceVideoRenderer(
      cancellation: cancellation,
      hostFactory: (_) {
        opened = true;
        throw StateError('must not open');
      },
      sandboxFactory: () {
        opened = true;
        throw StateError('must not open');
      },
    );
    await expectLater(
      renderer.render(
        composition: const SizedBox.shrink(),
        aspect: Aspect.square,
        duration: const Duration(seconds: 1),
      ),
      throwsA(isA<RenderCancelledException>()),
    );
    expect(opened, isFalse);
  });
}
