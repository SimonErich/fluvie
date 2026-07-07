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

    test('allows the public fluvie barrel', () {
      expect(disallowedImports("import 'package:fluvie/fluvie.dart';"), isEmpty);
    });

    test('rejects a package:fluvie/src path (private internals expose dart:io)', () {
      // IoProcessRunner (Process.run) and readFileBytes (File.readAsBytes) live
      // under src/ as public helpers; a src import must never be green-lit.
      expect(
        disallowedImports("import 'package:fluvie/src/rendering/platform/process_runner.dart';"),
        contains('package:fluvie/src/rendering/platform/process_runner.dart'),
      );
      expect(
        disallowedImports("import 'package:fluvie/src/media/io/file_bytes.dart';"),
        contains('package:fluvie/src/media/io/file_bytes.dart'),
      );
    });

    test('rejects the low-level rendering pipeline barrel', () {
      // rendering.dart re-exports the ffmpeg/process/file pipeline; a
      // composition only ever needs the public fluvie.dart barrel.
      expect(
        disallowedImports("import 'package:fluvie/rendering.dart';"),
        contains('package:fluvie/rendering.dart'),
      );
    });

    test('allows flutter public libraries but not flutter/src', () {
      expect(disallowedImports("import 'package:flutter/material.dart';"), isEmpty);
      expect(
        disallowedImports("import 'package:flutter/src/services/binary_messenger.dart';"),
        contains('package:flutter/src/services/binary_messenger.dart'),
      );
    });

    test('rejects an over-nested bracket bomb without a full parse', () {
      // A deeply-nested bomb would make the analyzer parser burn seconds of CPU;
      // the linear pre-scan rejects it instead.
      final bomb = 'Widget build() { return ${'(' * 5000}0${')' * 5000}; }';
      final result = disallowedImports(bomb);
      expect(result, isNotEmpty, reason: 'an over-nested source is rejected');
      expect(result.single, contains('nests too deeply'));
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

    test('rejects a conditional import that hides dart:io behind a config', () {
      const code =
          "import 'package:flutter/widgets.dart' "
          "if (dart.library.io) 'dart:io' as io;";
      expect(disallowedImports(code), contains('dart:io'));
    });

    test('rejects a conditional import that wraps across lines', () {
      const code = '''
import 'package:flutter/widgets.dart'
    if (dart.library.io) 'dart:io'
    as io;
''';
      expect(disallowedImports(code), contains('dart:io'));
    });

    test('rejects a conditional export too', () {
      const code = "export 'package:fluvie/fluvie.dart' if (dart.library.io) 'dart:io';";
      expect(disallowedImports(code), contains('dart:io'));
    });

    test('rejects a second directive sharing a physical line with an allowed one', () {
      // A line-anchored scan sees only the first directive; the real parser
      // sees both, so the smuggled dart:io is caught.
      expect(
        disallowedImports("import 'dart:math'; import 'dart:io';"),
        contains('dart:io'),
      );
    });

    test('rejects a directive hidden behind a leading block comment', () {
      expect(disallowedImports("/* c */ import 'dart:io';"), contains('dart:io'));
    });

    test('rejects a metadata-annotated directive', () {
      expect(
        disallowedImports("@Deprecated('x') import 'dart:io';"),
        contains('dart:io'),
      );
    });

    test('rejects an adjacent-string uri that concatenates to a banned library', () {
      // 'dart:' 'io' is one StringLiteral whose value is dart:io.
      expect(disallowedImports("import 'dart:' 'io';"), contains('dart:io'));
    });

    test('allows a conditional whose branches are all on the allowlist', () {
      const code =
          "import 'package:fluvie/fluvie.dart' "
          "if (dart.library.ui) 'package:flutter/widgets.dart';";
      expect(disallowedImports(code), isEmpty);
    });

    test('allows the flutter UI framework a real composition needs', () {
      const code = '''
import 'package:flutter/material.dart' hide Animation, Clip, Image, Tween;
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
