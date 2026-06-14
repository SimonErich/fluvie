import 'dart:io';

import 'package:test/test.dart';

import '../src/sync_snippets.dart';

/// A temp sandbox that mimics the repo layout: a `documentation/` tree and an
/// `example/lib/` source tree, with the tool resolving relpaths against the
/// sandbox root.
late Directory _root;

void _writeFile(String relPath, String content) {
  final file = File('${_root.path}/$relPath');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}

String _read(String relPath) => File('${_root.path}/$relPath').readAsStringSync();

void main() {
  setUp(() {
    _root = Directory.systemTemp.createTempSync('sync_snippets_test_');
  });

  tearDown(() {
    if (_root.existsSync()) _root.deleteSync(recursive: true);
  });

  group('sync (rewrite mode)', () {
    test('populates an empty fence body from a docregion', () {
      _writeFile('example/lib/snippets/demo.dart', '''
// header
// #docregion greeting
Widget hello() => const Text('hi');
// #enddocregion greeting
''');
      _writeFile('documentation/page.md', '''
# Page

<!-- code-excerpt "example/lib/snippets/demo.dart (greeting)" -->
```dart
```

Done.
''');

      final result = syncSnippets(rootDir: _root.path, check: false);

      expect(result.exitCode, 0);
      expect(result.changed, contains('documentation/page.md'));
      final md = _read('documentation/page.md');
      expect(md, contains("Widget hello() => const Text('hi');"));
      expect(md, isNot(contains('#docregion')));
    });

    test('strips common leading indentation and ignore comments', () {
      _writeFile('example/lib/snippets/demo.dart', '''
class C {
  // #docregion body
  // ignore: avoid_print
  void f() {
    final x = 1;
  }
  // #enddocregion body
}
''');
      _writeFile('documentation/page.md', '''
<!-- code-excerpt "example/lib/snippets/demo.dart (body)" -->
```dart
old content
```
''');

      syncSnippets(rootDir: _root.path, check: false);

      final md = _read('documentation/page.md');
      expect(md, contains('void f() {'));
      expect(md, contains('  final x = 1;'));
      // The leading two-space indent of the region is stripped.
      expect(md, isNot(contains('  void f() {')));
      // ignore comments are dropped from docs.
      expect(md, isNot(contains('avoid_print')));
      expect(md, isNot(contains('old content')));
    });

    test('trims blank lines padding the region markers', () {
      _writeFile('example/lib/snippets/demo.dart', '''
Widget before() => const SizedBox();
// #docregion padded

final x = 1;

// #enddocregion padded
''');
      _writeFile('documentation/page.md', '''
<!-- code-excerpt "example/lib/snippets/demo.dart (padded)" -->
```dart
```
''');

      syncSnippets(rootDir: _root.path, check: false);

      final md = _read('documentation/page.md');
      expect(md, contains('```dart\nfinal x = 1;\n```'));
    });

    test('drops a nested region marker from the outer fence', () {
      _writeFile('example/lib/snippets/demo.dart', '''
// #docregion outer
final a = 1;
// #docregion inner
final b = 2;
// #enddocregion inner
final c = 3;
// #enddocregion outer
''');
      _writeFile('documentation/page.md', '''
<!-- code-excerpt "example/lib/snippets/demo.dart (outer)" -->
```dart
```
''');

      syncSnippets(rootDir: _root.path, check: false);

      final md = _read('documentation/page.md');
      expect(md, contains('final a = 1;'));
      expect(md, contains('final b = 2;'));
      expect(md, contains('final c = 3;'));
      expect(md, isNot(contains('#docregion')));
      expect(md, isNot(contains('#enddocregion')));
    });

    test('replaces an already-populated fence (idempotent re-sync)', () {
      _writeFile('example/lib/snippets/demo.dart', '''
// #docregion a
final answer = 42;
// #enddocregion a
''');
      _writeFile('documentation/page.md', '''
<!-- code-excerpt "example/lib/snippets/demo.dart (a)" -->
```dart
final answer = 41;
```
''');

      final first = syncSnippets(rootDir: _root.path, check: false);
      expect(first.changed, isNotEmpty);
      expect(_read('documentation/page.md'), contains('final answer = 42;'));

      // Running again changes nothing.
      final second = syncSnippets(rootDir: _root.path, check: false);
      expect(second.changed, isEmpty);
    });
  });

  group('check mode', () {
    test('passes (exit 0) when fences are in sync', () {
      _writeFile('example/lib/snippets/demo.dart', '''
// #docregion a
final answer = 42;
// #enddocregion a
''');
      _writeFile('documentation/page.md', '''
<!-- code-excerpt "example/lib/snippets/demo.dart (a)" -->
```dart
final answer = 42;
```
''');

      final result = syncSnippets(rootDir: _root.path, check: true);
      expect(result.exitCode, 0);
      expect(result.drift, isEmpty);
    });

    test('fails (non-zero) and reports drift without changing files', () {
      _writeFile('example/lib/snippets/demo.dart', '''
// #docregion a
final answer = 42;
// #enddocregion a
''');
      const tampered = '''
<!-- code-excerpt "example/lib/snippets/demo.dart (a)" -->
```dart
final answer = 999;
```
''';
      _writeFile('documentation/page.md', tampered);

      final result = syncSnippets(rootDir: _root.path, check: true);
      expect(result.exitCode, isNot(0));
      expect(result.drift, isNotEmpty);
      // Nothing was written.
      expect(_read('documentation/page.md'), tampered);
    });
  });

  group('validation', () {
    test('a missing source file is a hard error', () {
      _writeFile('documentation/page.md', '''
<!-- code-excerpt "example/lib/snippets/missing.dart (a)" -->
```dart
```
''');

      final result = syncSnippets(rootDir: _root.path, check: false);
      expect(result.exitCode, isNot(0));
      expect(result.errors.join('\n'), contains('missing.dart'));
    });

    test('a missing region is a hard error', () {
      _writeFile('example/lib/snippets/demo.dart', '''
// #docregion present
final x = 1;
// #enddocregion present
''');
      _writeFile('documentation/page.md', '''
<!-- code-excerpt "example/lib/snippets/demo.dart (absent)" -->
```dart
```
''');

      final result = syncSnippets(rootDir: _root.path, check: false);
      expect(result.exitCode, isNot(0));
      expect(result.errors.join('\n'), contains('absent'));
    });

    test('an unterminated region is a hard error', () {
      _writeFile('example/lib/snippets/demo.dart', '''
// #docregion open
final x = 1;
''');
      _writeFile('documentation/page.md', '''
<!-- code-excerpt "example/lib/snippets/demo.dart (open)" -->
```dart
```
''');

      final result = syncSnippets(rootDir: _root.path, check: false);
      expect(result.exitCode, isNot(0));
      expect(result.errors.join('\n'), contains('open'));
    });
  });

  group('edge cases', () {
    test('a missing documentation/ tree is a clean no-op', () {
      final result = syncSnippets(rootDir: _root.path, check: true);
      expect(result.exitCode, 0);
      expect(result.changed, isEmpty);
      expect(result.drift, isEmpty);
      expect(result.errors, isEmpty);
    });

    test('a directive not followed by a dart fence is skipped', () {
      _writeFile('example/lib/snippets/demo.dart', '''
// #docregion a
final x = 1;
// #enddocregion a
''');
      const md = '''
<!-- code-excerpt "example/lib/snippets/demo.dart (a)" -->
Some prose, not a fence.
''';
      _writeFile('documentation/page.md', md);

      final result = syncSnippets(rootDir: _root.path, check: false);
      expect(result.exitCode, 0);
      expect(result.changed, isEmpty);
      expect(_read('documentation/page.md'), md);
    });

    test('an unterminated fence after a directive is a hard error', () {
      _writeFile('example/lib/snippets/demo.dart', '''
// #docregion a
final x = 1;
// #enddocregion a
''');
      _writeFile('documentation/page.md', '''
<!-- code-excerpt "example/lib/snippets/demo.dart (a)" -->
```dart
final x = 1;
''');

      final result = syncSnippets(rootDir: _root.path, check: false);
      expect(result.exitCode, isNot(0));
      expect(result.errors.join('\n'), contains('not closed'));
    });

    test('a trailing fence-language tag (```dart name) is recognized', () {
      _writeFile('example/lib/snippets/demo.dart', '''
// #docregion a
final x = 1;
// #enddocregion a
''');
      _writeFile('documentation/page.md', '''
<!-- code-excerpt "example/lib/snippets/demo.dart (a)" -->
```dart title
```
''');

      syncSnippets(rootDir: _root.path, check: false);
      expect(_read('documentation/page.md'), contains('final x = 1;'));
    });

    test('a trailing slash on the root is tolerated', () {
      _writeFile('example/lib/snippets/demo.dart', '''
// #docregion a
final x = 1;
// #enddocregion a
''');
      _writeFile('documentation/page.md', '''
<!-- code-excerpt "example/lib/snippets/demo.dart (a)" -->
```dart
```
''');

      final result = syncSnippets(rootDir: '${_root.path}/', check: false);
      expect(result.exitCode, 0);
      expect(_read('documentation/page.md'), contains('final x = 1;'));
    });
  });

  group('the code-excerpt-ignore opt-out', () {
    test('a fence preceded by the ignore marker is left untouched', () {
      const md = '''
<!-- code-excerpt-ignore: illustrates raw syntax -->
```dart
// coverage:ignore-line: reason here
```
''';
      _writeFile('documentation/contributing/coverage.md', md);

      final result = syncSnippets(rootDir: _root.path, check: true);
      expect(result.exitCode, 0);
      expect(_read('documentation/contributing/coverage.md'), md);
    });
  });
}
