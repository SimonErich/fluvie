import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/rendering.dart';

void main() {
  test('operation errors remain observable and losing cancelled work is consumed', () async {
    final failure = StateError('original failure');
    await expectLater(
      RenderCancellation().run<int>(() => throw failure),
      throwsA(same(failure)),
    );
    final cancellation = RenderCancellation();
    final operation = Completer<int>();
    final pending = cancellation.run(() => operation.future);
    final result = expectLater(pending, throwsA(isA<RenderCancelledException>()));
    await Future<void>.value();
    cancellation.cancel();
    await result;
    operation.completeError(StateError('backend stopped after cancellation'));
    await Future<void>.value();
  });

  test('cancelling before a queued stage starts prevents its side effects', () async {
    final cancellation = RenderCancellation();
    var started = false;
    final pending = cancellation.run(() async {
      started = true;
      return 1;
    });
    final result = expectLater(pending, throwsA(isA<RenderCancelledException>()));
    cancellation.cancel();
    await result;
    expect(started, false);
  });

  test('cancel interrupts pending preparation and never starts cancelled work', () async {
    final cancellation = RenderCancellation();
    final pending = cancellation.run(() => Completer<int>().future);
    final result = expectLater(pending, throwsA(isA<RenderCancelledException>()));
    cancellation.cancel();
    await result;
    var started = false;
    await expectLater(
      cancellation.run(() async {
        started = true;
        return 1;
      }),
      throwsA(isA<RenderCancelledException>()),
    );
    expect(started, isFalse);
  });
}
