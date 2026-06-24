import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/errors/fluvie_generative_exception.dart';

void main() {
  test('FluvieGenerativeException carries its message in toString', () {
    final error = FluvieGenerativeException('veo failed for "a cat"');
    expect(error.message, 'veo failed for "a cat"');
    expect(error.toString(), contains('veo failed for "a cat"'));
    expect(error.toString(), contains('FluvieGenerativeException'));
  });

  test('is an Exception', () {
    expect(FluvieGenerativeException('x'), isA<Exception>());
  });
}
