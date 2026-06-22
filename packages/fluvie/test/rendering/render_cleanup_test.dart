import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/rendering/render_cleanup.dart';

void main() {
  group('runGuarded', () {
    test('runs every cleanup in order', () async {
      final order = <int>[];
      await runGuarded([
        () async => order.add(1),
        () async => order.add(2),
      ], (_, _) {});
      expect(order, [1, 2]);
    });

    test('routes a cleanup error to onError and still runs the rest', () async {
      final order = <int>[];
      final errors = <Object>[];
      await runGuarded([
        () async => order.add(1),
        () async => throw StateError('boom'),
        () async => order.add(3),
      ], (error, _) => errors.add(error));
      expect(order, [1, 3]);
      expect(errors.single, isStateError);
    });

    test('never throws, even when a cleanup throws', () async {
      await expectLater(
        runGuarded([() async => throw Exception('x')], (_, _) {}),
        completes,
      );
    });
  });
}
