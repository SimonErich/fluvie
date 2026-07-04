/// Analyzes a Fluvie snippet and prints its diagnostics.
///
/// Run it from a directory whose package config resolves `package:fluvie`
/// (a project that depends on fluvie, or this repository's root):
/// `dart run example/main.dart`. The analyzer only inspects the code; the
/// snippet is never compiled to an executable or run.
library;

import 'dart:io';

import 'package:fluvie_validate/fluvie_validate.dart';

Future<void> main() async {
  final analyzer = FluvieCodeAnalyzer(projectRoot: Directory.current);

  // `Scene` takes `children`, so the `child:` below is a deliberate error.
  const snippet = '''
import 'package:fluvie/fluvie.dart';

Video build() => Video(
  size: VideoSize.square,
  scenes: [Scene(duration: 2.seconds, child: null)],
);
''';

  final diagnostics = await analyzer.analyze(snippet);
  for (final diagnostic in diagnostics) {
    stdout.writeln(
      '${diagnostic.severity.name} at ${diagnostic.line}:${diagnostic.column} '
      '${diagnostic.message}',
    );
  }
}
