import 'dart:io';

import 'package:fluvie_cli/docs.dart';
import 'package:test/test.dart';

void main() {
  test('offline corpus includes canonical authoring pages and unique paths', () {
    expect(bundledDocumentation.length, greaterThan(60));
    expect(
      bundledDocumentation.map((page) => page.path).toSet().length,
      bundledDocumentation.length,
    );
    expect(authoringContext(), contains('Video build()'));
    expect(authoringContext(), contains('fluvie render ./lib/my_video.dart'));
  });

  test('documentation version follows the installed CLI release', () {
    final version = RegExp(
      r'^version:\s*(.+)$',
      multiLine: true,
    ).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1)!;
    expect(documentationVersion, version);
    expect(documentationDigest, matches(RegExp(r'^[a-f0-9]{64}$')));
  });
  test(
    'Dart editing context selects installed, compiled caption examples within its byte budget',
    () {
      final context = dartEditingContext('Add captions with a custom style');
      expect(context, contains('Captions.fromSrt'));
      expect(context, contains('background: Color(0x80000000)'));
      expect(context, contains(documentationDigest));
      expect(context.length, lessThanOrEqualTo(32768));
      expect(dartEditingContext('Rename a title'), isNot(contains('benchmarkCaptionStyle')));
    },
  );
}
