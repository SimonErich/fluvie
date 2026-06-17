import 'package:fluvie_api/src/config/duration_parsing.dart';
import 'package:test/test.dart';

void main() {
  group('parseHumanDuration', () {
    test('parses every unit', () {
      expect(parseHumanDuration('500ms'), const Duration(milliseconds: 500));
      expect(parseHumanDuration('90s'), const Duration(seconds: 90));
      expect(parseHumanDuration('30m'), const Duration(minutes: 30));
      expect(parseHumanDuration('24h'), const Duration(hours: 24));
      expect(parseHumanDuration('7d'), const Duration(days: 7));
    });

    test('trims surrounding whitespace', () {
      expect(parseHumanDuration('  12h '), const Duration(hours: 12));
    });

    test('throws a FormatException naming the label for bad input', () {
      for (final bad in ['', '10', 'h', '1x', '-3h', '1.5h', '10 h', 'abc']) {
        expect(
          () => parseHumanDuration(bad, label: 'FILE_TTL'),
          throwsA(
            isA<FormatException>().having((e) => e.message, 'message', contains('FILE_TTL')),
          ),
          reason: 'should reject "$bad"',
        );
      }
    });
  });
}
