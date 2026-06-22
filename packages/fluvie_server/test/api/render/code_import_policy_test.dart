import 'package:fluvie_server/src/api/render/code_import_policy.dart';
import 'package:test/test.dart';

void main() {
  group('disallowedImports', () {
    test('an empty list for snippet using only allowed imports', () {
      const code = '''
import 'package:fluvie/fluvie.dart';
import 'dart:math';
import 'dart:ui';

Video build() => Video(scenes: const []);
''';
      expect(disallowedImports(code), isEmpty);
    });

    test('allows a sub-path under package:fluvie', () {
      expect(disallowedImports("import 'package:fluvie/src/whatever.dart';"), isEmpty);
    });

    test('rejects dart:io', () {
      expect(disallowedImports("import 'dart:io';"), contains('dart:io'));
    });

    test('rejects dart:ffi, dart:isolate, dart:mirrors', () {
      const code = '''
import 'dart:ffi';
import 'dart:isolate';
import 'dart:mirrors';
''';
      expect(disallowedImports(code), containsAll(['dart:ffi', 'dart:isolate', 'dart:mirrors']));
    });

    test('rejects an arbitrary network/http package', () {
      expect(
        disallowedImports("import 'package:http/http.dart';"),
        contains('package:http/http.dart'),
      );
    });

    test('rejects an arbitrary third-party package', () {
      expect(
        disallowedImports("import 'package:path_provider/path_provider.dart';"),
        contains('package:path_provider/path_provider.dart'),
      );
    });

    test('handles double or single quotes and the as/show/hide clauses', () {
      const code = '''
import "dart:io" as io;
import 'package:fluvie/fluvie.dart' show Video;
''';
      expect(disallowedImports(code), contains('dart:io'));
      expect(disallowedImports(code), isNot(contains('package:fluvie/fluvie.dart')));
    });

    test('ignores an import-like string inside a comment or body', () {
      const code = '''
// import 'dart:io';
Video build() {
  final s = "import 'dart:ffi';"; // not a directive
  return Video(scenes: const []);
}
''';
      expect(disallowedImports(code), isEmpty);
    });

    test('rejects an export of a disallowed library too', () {
      expect(disallowedImports("export 'dart:io';"), contains('dart:io'));
    });

    test('allows the flutter UI framework a real composition needs', () {
      const code = '''
import 'package:flutter/material.dart' hide Animation;
import 'package:flutter/widgets.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/animation.dart';
''';
      expect(disallowedImports(code), isEmpty);
    });
  });

  group('CodeImportException', () {
    test('names every rejected library in its message', () {
      final error = CodeImportException(['dart:io', 'package:http']);
      expect(error.message, contains('dart:io'));
      expect(error.message, contains('package:http'));
      expect(error.disallowed, ['dart:io', 'package:http']);
      expect(error.toString(), contains('CodeImportException'));
      expect(error.toString(), contains('dart:io'));
    });
  });
}
