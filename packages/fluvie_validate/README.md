# fluvie_validate

Static validation for [Fluvie](https://pub.dev/packages/fluvie) composition code.
It resolves a snippet against `package:fluvie` and reports the compiler
diagnostics plus the [fluvie_lints](https://pub.dev/packages/fluvie_lints) rules.
It analyzes only: it never compiles the code to an executable or runs it, so
validating an untrusted snippet is safe.

[![pub package](https://img.shields.io/pub/v/fluvie_validate.svg)](https://pub.dev/packages/fluvie_validate)
[![license: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)

## Usage

```dart
import 'dart:io';

import 'package:fluvie_validate/fluvie_validate.dart';

Future<void> main() async {
  final analyzer = FluvieCodeAnalyzer(projectRoot: Directory.current);

  final diagnostics = await analyzer.analyze('''
import 'package:fluvie/fluvie.dart';

Video build() => Video(scenes: const []);
''');

  if (diagnostics.isEmpty) {
    stderr.writeln('No problems.');
  } else {
    for (final diagnostic in diagnostics) {
      stderr.writeln(diagnostic);
    }
  }
}
```

`projectRoot` is any directory whose package resolution can see `package:fluvie`
(the workspace root works). This package backs the validate path in
[fluvie_server](https://pub.dev/packages/fluvie_server) and the Fluvie Playground.
