import 'package:flutter_test/flutter_test.dart';
import 'package:slides/loader/autosave_record.dart';

AutosaveRecord _record({int at = 5000}) => AutosaveRecord(
  json: '{"fluvieSpec": 1}',
  savedAt: DateTime.fromMillisecondsSinceEpoch(at),
  digest: 'abc123',
);

void main() {
  group('AutosaveRecord', () {
    test('round-trips through its stored text form', () {
      final decoded = decodeAutosaveRecord(encodeAutosaveRecord(_record()));
      expect(decoded, isNotNull);
      expect(decoded!.json, '{"fluvieSpec": 1}');
      expect(decoded.savedAt, DateTime.fromMillisecondsSinceEpoch(5000));
      expect(decoded.digest, 'abc123');
      expect(decoded.version, autosaveFormatVersion);
    });

    test('rejects garbage, foreign JSON, and junk fields', () {
      expect(decodeAutosaveRecord(null), isNull);
      expect(decodeAutosaveRecord(''), isNull);
      expect(decodeAutosaveRecord('{broken'), isNull);
      expect(decodeAutosaveRecord('[1, 2]'), isNull);
      expect(decodeAutosaveRecord('{"version": 1}'), isNull);
      expect(decodeAutosaveRecord('{"version": 1, "json": 7, "digest": "d"}'), isNull);
      expect(decodeAutosaveRecord('{"version": 1, "json": "{}", "digest": ""}'), isNull);
    });

    test('rejects records from an unknown format version', () {
      const foreign =
          '{"version": ${autosaveFormatVersion + 1}, "json": "{}", '
          '"digest": "d", "savedAt": 1}';
      expect(decodeAutosaveRecord(foreign), isNull);
    });

    test('tolerates a missing timestamp (reads as the epoch)', () {
      final decoded = decodeAutosaveRecord('{"version": 1, "json": "{}", "digest": "d"}');
      expect(decoded, isNotNull);
      expect(decoded!.savedAt, DateTime.fromMillisecondsSinceEpoch(0));
    });
  });

  group('relativeTimeLabel', () {
    final now = DateTime(2026, 7, 19, 12);

    test('under a minute reads as just now (clock skew included)', () {
      expect(relativeTimeLabel(now.subtract(const Duration(seconds: 5)), now), 'just now');
      expect(relativeTimeLabel(now.subtract(const Duration(seconds: 59)), now), 'just now');
      expect(relativeTimeLabel(now.add(const Duration(minutes: 3)), now), 'just now');
    });

    test('minutes and hours read as ago', () {
      expect(relativeTimeLabel(now.subtract(const Duration(minutes: 1)), now), '1m ago');
      expect(relativeTimeLabel(now.subtract(const Duration(minutes: 59)), now), '59m ago');
      expect(relativeTimeLabel(now.subtract(const Duration(hours: 1)), now), '1h ago');
      expect(relativeTimeLabel(now.subtract(const Duration(hours: 23)), now), '23h ago');
    });

    test('a day or older reads as a date', () {
      expect(relativeTimeLabel(now.subtract(const Duration(hours: 24)), now), 'on 2026-07-18');
      expect(relativeTimeLabel(DateTime(2026, 1, 2), now), 'on 2026-01-02');
    });
  });
}
