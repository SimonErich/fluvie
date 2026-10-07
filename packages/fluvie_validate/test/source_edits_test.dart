import 'dart:convert';

import 'package:fluvie_validate/source_edits.dart';
import 'package:test/test.dart';

void main() {
  String patch(List<Map<String, String>> edits) => jsonEncode({'edits': edits});
  test('pure edits preserve Unicode, CRLF and all unrelated source bytes', () {
    const source = '// 猫\r\nduration: 3.seconds, delay: 0.3.seconds\r\n';
    expect(
      applyDartSourceEdits(
        source,
        patch([
          {'before': 'duration: 3.seconds', 'after': 'duration: 4.seconds'},
          {'before': '// 猫', 'after': '// Milo 猫'},
        ]),
      ),
      '// Milo 猫\r\nduration: 4.seconds, delay: 0.3.seconds\r\n',
    );
    expect(
      applyDartSourceEdits(
        'x',
        '```json\n${patch([
          {'before': 'x', 'after': 'y'},
        ])}\n```',
      ),
      'y',
    );
  });
  for (final reply in [
    '{',
    '[]',
    '{}',
    '{"edits":[]}',
    '{"edits":[{"before":"","after":"x"}]}',
    '{"edits":[{"before":"x","after":"y","extra":true}]}',
    patch([
      {'before': 'missing', 'after': 'y'},
    ]),
    patch([
      {'before': 'a', 'after': 'y'},
      {'before': 'ab', 'after': 'z'},
    ]),
    patch(List.filled(33, {'before': 'a', 'after': 'b'})),
  ]) {
    test('rejects invalid patch ${reply.substring(0, reply.length.clamp(0, 50))}', () {
      expect(() => applyDartSourceEdits('xab', reply), throwsA(isA<SourceEditException>()));
    });
  }
  test('bounds source, response and resulting UTF-8 bytes', () {
    final large = 'a' * (256 * 1024);
    expect(
      () => applyDartSourceEdits(
        '$large!',
        patch([
          {'before': '!', 'after': '?'},
        ]),
      ),
      throwsA(isA<SourceEditException>()),
    );
    expect(() => applyDartSourceEdits('x', '$large '), throwsA(isA<SourceEditException>()));
    expect(
      () => applyDartSourceEdits(
        'x${large.substring(1)}',
        patch([
          {'before': 'x', 'after': '猫'},
        ]),
      ),
      throwsA(isA<SourceEditException>()),
    );
  });
}
