import 'package:fluvie_server/src/config/env_trim.dart';
import 'package:test/test.dart';

void main() {
  group('trimToNull', () {
    test('null stays null', () {
      expect(trimToNull(null), isNull);
    });

    test('empty becomes null', () {
      expect(trimToNull(''), isNull);
    });

    test('whitespace-only becomes null', () {
      expect(trimToNull('   \t'), isNull);
    });

    test('padded value is trimmed', () {
      expect(trimToNull('  token  '), 'token');
    });

    test('clean value passes through', () {
      expect(trimToNull('token'), 'token');
    });
  });
}
