import 'dart:convert';

import 'package:fluvie_cli/docs.dart';
import 'package:fluvie_cli/src/cli_runner.dart' as cli;
import 'package:test/test.dart';

void main() {
  test('authoring context is available offline with versioned JSON metadata', () async {
    final out = StringBuffer();
    final err = StringBuffer();
    expect(await cli.run(['docs', '--context', '--json'], out: out, err: err), 0);
    final result = jsonDecode(out.toString()) as Map;
    expect(result['version'], documentationVersion);
    expect(result['digest'], documentationDigest);
    expect(result['context'], contains('fluvie render'));
    expect(err.toString(), isEmpty);
  });
  test('listing and reading use the same canonical bundled page', () async {
    final out = StringBuffer();
    final err = StringBuffer();
    expect(await cli.run(['docs', '--json'], out: out, err: err), 0);
    final pages = (jsonDecode(out.toString()) as Map)['pages'] as List;
    final path = (pages.first as Map)['path'] as String;
    out.clear();
    expect(await cli.run(['docs', path], out: out, err: err), 0);
    expect(out.toString().trim(), bundledDocumentation.first.body.trim());
  });
  test('unknown pages, conflicting context and unknown flags fail clearly', () async {
    for (final args in [
      ['docs', 'missing-page'],
      ['docs', 'page', '--context'],
      ['docs', '--unknown'],
    ]) {
      final err = StringBuffer();
      expect(await cli.run(args, out: StringBuffer(), err: err), 64);
      expect(err.toString(), isNotEmpty);
    }
  });
}
