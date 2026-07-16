import 'dart:convert';
import 'dart:io';

import 'package:dart_style/dart_style.dart';
import 'package:fluvie_cli/src/codegen/dart_spec_printer.dart';
import 'package:test/test.dart';

/// The printer half of the conformance corpus: every fixture fluvie accepts
/// must print to syntactically valid Dart (the formatter parses it), so the
/// JSON codecs and the Dart printer stay in lockstep.
void main() {
  final corpus = Directory('../fluvie/test/serialization/corpus')
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.fluvie.json'))
      .toList(growable: false);

  test('the corpus is visible from the printer', () {
    expect(corpus, isNotEmpty);
  });

  for (final file in corpus) {
    test('${file.uri.pathSegments.last} prints to valid Dart', () {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      final code = printVideoSpecJson(json);
      final formatter = DartFormatter(languageVersion: DartFormatter.latestLanguageVersion);
      expect(() => formatter.format(code), returnsNormally);
    });
  }
}
