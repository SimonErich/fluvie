import 'dart:io';

import 'package:fluvie_cli/src/project_context.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('fluvie_ctx_'));
  tearDown(() => dir.deleteSync(recursive: true));

  void writePubspec(String body) => File('${dir.path}/pubspec.yaml').writeAsStringSync(body);

  test('defaults to the current directory when none is given', () {
    final context = detectProjectContext();
    expect(context.directory.path, isNotEmpty);
  });

  test('no pubspec is not a Flutter project', () {
    final context = detectProjectContext(dir);
    expect(context.isFlutterProject, isFalse);
    expect(context.packageName, isNull);
    expect(context.hasFluvieDependency, isFalse);
  });

  test('a Flutter project is detected with its package name', () {
    writePubspec('''
name: my_app
dependencies:
  flutter:
    sdk: flutter
''');
    final context = detectProjectContext(dir);
    expect(context.isFlutterProject, isTrue);
    expect(context.packageName, 'my_app');
    expect(context.hasFluvieDependency, isFalse);
  });

  test('an existing fluvie dependency is detected', () {
    writePubspec('''
name: my_app
dependencies:
  flutter:
    sdk: flutter
  fluvie: ^0.1.0
''');
    expect(detectProjectContext(dir).hasFluvieDependency, isTrue);
  });

  test('a pure Dart package (no flutter dep) is not a Flutter project', () {
    writePubspec('''
name: cli_tool
dependencies:
  args: ^2.0.0
''');
    final context = detectProjectContext(dir);
    expect(context.isFlutterProject, isFalse);
    expect(context.packageName, 'cli_tool');
  });
}
