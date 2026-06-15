import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/core/errors/fluvie_snapshot_unavailable_error.dart';

void main() {
  group('FluvieSnapshotUnavailableError', () {
    test('stores the message verbatim', () {
      final error = FluvieSnapshotUnavailableError('Chrome not found');
      expect(error.message, 'Chrome not found');
    });

    test('toString names the type and the message', () {
      final error = FluvieSnapshotUnavailableError('Chrome not found');
      expect(error.toString(), startsWith('FluvieSnapshotUnavailableError:'));
      expect(error.toString(), contains('Chrome not found'));
    });

    test('toString appends the install hint when one is given', () {
      final error = FluvieSnapshotUnavailableError(
        'Chrome not found',
        installHint: 'apt install chromium',
      );
      expect(error.toString(), contains('apt install chromium'));
    });

    test('toString omits the hint section when none is given', () {
      final error = FluvieSnapshotUnavailableError('no binary');
      expect(error.toString(), isNot(contains('To fix')));
    });

    test('is catchable as an Exception', () {
      expect(
        () => throw FluvieSnapshotUnavailableError('boom'),
        throwsA(isA<Exception>()),
      );
    });

    test('is a sibling to FluvieRenderException, not a subtype', () {
      // D-Errors: a missing *capability* is distinct from a render fault, so it
      // does not extend FluvieRenderException — a render catch must not swallow
      // "install Chrome".
      final error = FluvieSnapshotUnavailableError('no binary');
      expect(error, isNot(isA<FluvieRenderException>()));
    });

    test('exposes the install hint field', () {
      final error = FluvieSnapshotUnavailableError('x', installHint: 'do y');
      expect(error.installHint, 'do y');
    });
  });
}
