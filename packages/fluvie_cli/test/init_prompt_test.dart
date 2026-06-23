import 'dart:collection';

import 'package:fluvie_cli/src/init_prompt.dart';
import 'package:test/test.dart';

void main() {
  LineReader feed(List<String?> lines) {
    final queue = Queue<String?>.of(lines);
    return () => queue.isEmpty ? null : queue.removeFirst();
  }

  test('ask returns the typed answer and shows the default', () {
    final out = StringBuffer();
    final prompt = InitPrompt(out: out, readLine: feed(['typed']));
    expect(prompt.ask('Where?', defaultValue: 'lib/x.dart'), 'typed');
    expect(out.toString(), contains('Where? [lib/x.dart]:'));
  });

  test('ask returns the default on empty input or end of input', () {
    expect(
      InitPrompt(out: StringBuffer(), readLine: feed([''])).ask('q', defaultValue: 'd'),
      'd',
    );
    expect(
      InitPrompt(out: StringBuffer(), readLine: feed([null])).ask('q', defaultValue: 'd'),
      'd',
    );
  });

  test('confirm reads yes/no and defaults on Enter', () {
    expect(InitPrompt(out: StringBuffer(), readLine: feed(['y'])).confirm('ok?'), isTrue);
    expect(InitPrompt(out: StringBuffer(), readLine: feed(['no'])).confirm('ok?'), isFalse);
    expect(InitPrompt(out: StringBuffer(), readLine: feed([''])).confirm('ok?'), isTrue);
    expect(
      InitPrompt(out: StringBuffer(), readLine: feed([''])).confirm('ok?', defaultYes: false),
      isFalse,
    );
  });
}
