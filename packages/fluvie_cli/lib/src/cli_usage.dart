part of 'cli_runner.dart';

String _usage(ArgParser parser) =>
    '''
fluvie - headless renderer for Fluvie compositions.

Usage:
  fluvie init [--name <name>] [--dir <project>]
  fluvie preview <file.dart> [-d <device>]
  fluvie workspace <file.dart> [--json]
  fluvie session <session.json> <status|source|frame|review|render|inspect>
  fluvie bundle <create|inspect|unpack|replay> <video.dart|bundle.zip> [options]
  fluvie benchmark <suite.json> --project <fixture-project> --model <model> [options]
  fluvie render <file.dart> [--out <file>] [options]
  fluvie render --spec <file.fluvie.json> [--out <file>] [options]
  fluvie generate "<prompt>" [--out <file>] [--dart-out <file.dart>] [--no-render] [--provider <name>] [options]
  fluvie edit <file.dart|file.fluvie.json> "<change>" [--out <file>] [--no-render] [options]
  fluvie list [--project <dir>]
  fluvie ffmpeg <install|path|status|uninstall>
  fluvie doctor [--json]
  fluvie assets [directory] [--json]
  fluvie validate <file.dart> [--json]
  fluvie docs [page] [--context] [--json]
  fluvie inspect <file.dart> [--json]
  fluvie frame <file.dart> [--frame <index>] [--out <png>] [--json]
  fluvie review <file.dart> [--samples <indexes>] [--determinism] [--render] [--strict-decode] [--json]

A Fluvie project is a composition file, an `assets/` folder, and a pubspec.
`init` scaffolds one. `preview` runs it live with hot reload; `render` captures
it under `flutter test` and encodes it with ffmpeg. Both take the .dart file
directly and generate whatever they need, so there is no app or harness to
maintain. A composition file exposes a top-level `Video build()` (`--entry`
names another). `generate` publishes readable Flutter code and its VideoSpec
before rendering; `edit` safely patches Dart source or refines a spec. `list` prints the render
keys of a project that still uses a registry. `ffmpeg` manages the FFmpeg build
Fluvie downloads so renders work without a manual install.

Init options:
${InitCommand.buildParser().usage}

Preview options:
${PreviewCommand.buildParser().usage}

Render options:
${RenderCommand.buildParser().usage}

Generate options:
${GenerateCommand.buildParser().usage}

List options:
${ListCommand.buildParser().usage}

Global options:
${parser.usage}''';
