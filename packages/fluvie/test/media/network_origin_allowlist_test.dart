import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/rendering.dart';

void main() {
  test('explicit origin admits only its own scheme, host and port', () {
    final gate = NetworkAllowlist.allowAny(origins: const {'http://localhost:8140'})
      ..check(Uri.parse('http://localhost:8140/v1/media/input?token=signed'))
      ..check(Uri.parse('https://example.com/image.png'));
    for (final url in [
      'http://localhost:8141/v1/media/input',
      'http://127.0.0.1:8140/v1/media/input',
      'http://other.example/image.png',
    ]) {
      expect(() => gate.check(Uri.parse(url)), throwsA(isA<Exception>()));
    }
  });
  test('default policy still rejects HTTP', () {
    expect(
      () => NetworkAllowlist.allowAny().check(Uri.parse('http://localhost:8140/image.png')),
      throwsA(isA<Exception>()),
    );
  });
}
