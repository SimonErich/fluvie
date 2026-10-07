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

  try {
    final diagnostics = await analyzer.analyze('''
import 'package:fluvie/fluvie.dart';

Video build() => Video(scenes: const []);
''');

    if (diagnostics.isEmpty) {
      stderr.writeln('No problems.');
    } else {
      diagnostics.forEach(stderr.writeln);
    }
  } finally {
    await analyzer.dispose();
  }
}
```

`projectRoot` is any directory whose package resolution can see `package:fluvie`
(the workspace root works). This package backs the validate path in
[fluvie_server](https://pub.dev/packages/fluvie_server) and the Fluvie Playground.

Use `analyzeFile('lib/my_video.dart')` to validate an existing composition in
place. Relative imports resolve from its original directory, file changes refresh
in the reusable analysis context, and this path writes no scratch file.
Diagnostics include 1-based locations, stable `toJson()` data, and readable
`toString()` output. Call `dispose()` after the final request. The CLI exposes
this through `fluvie validate lib/my_video.dart --json`.

Fluvie warnings honor standard `ignore`, `ignore_for_file` and `type=lint`
comment directives, including when analyzed programmatically. Text inside a
string is never a directive. Compiler errors remain visible unless their own
analyzer diagnostic is explicitly suppressed. The `nondeterministic_video`
warning catches obvious clock and unseeded random reads in authored video code;
runtime review checks sampled pixels across seeking and a fresh mount.
