import 'package:args/args.dart';
import 'package:fluvie_cli/src/edit_command.dart';
import 'package:fluvie_cli/src/ffmpeg_command.dart';
import 'package:fluvie_cli/src/generate_command.dart';
import 'package:fluvie_cli/src/init_command.dart';
import 'package:fluvie_cli/src/list_command.dart';
import 'package:fluvie_cli/src/preview_command.dart';
import 'package:fluvie_cli/src/render_command.dart';

/// BSD `EX_USAGE`: the command line was used incorrectly.
const int exitUsage = 64;

/// Parses [args] and runs the requested command, writing human-readable
/// output to [out] and errors to [err]. Returns the process exit code.
///
/// `render` is injectable so wiring tests can run without spawning a single
/// process; the default constructs the real command.
Future<int> run(
  List<String> args, {
  required StringSink out,
  required StringSink err,
  RenderCommand? render,
  ListCommand? list,
  GenerateCommand? generate,
  EditCommand? edit,
  FfmpegCommand? ffmpeg,
  InitCommand? init,
  PreviewCommand? preview,
}) async {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this usage.')
    ..addCommand('init', InitCommand.buildParser())
    ..addCommand('render', RenderCommand.buildParser())
    ..addCommand('preview', PreviewCommand.buildParser())
    ..addCommand('generate', GenerateCommand.buildParser())
    ..addCommand('edit', EditCommand.buildParser())
    ..addCommand('list', ListCommand.buildParser())
    ..addCommand('ffmpeg', FfmpegCommand.buildParser());

  final ArgResults results;
  try {
    results = parser.parse(args);
  } on FormatException catch (e) {
    err
      ..writeln(e.message)
      ..writeln()
      ..writeln(_usage(parser));
    return exitUsage;
  }

  if (results.flag('help')) {
    out.writeln(_usage(parser));
    return 0;
  }

  final command = results.command;
  if (command == null) {
    err.writeln(_usage(parser));
    return exitUsage;
  }
  return switch (command.name) {
    'init' => (init ?? InitCommand()).execute(command, out: out, err: err),
    'preview' => (preview ?? PreviewCommand()).execute(command, out: out, err: err),
    'list' => (list ?? ListCommand()).execute(command, out: out, err: err),
    'generate' => (generate ?? GenerateCommand()).execute(command, out: out, err: err),
    'edit' => (edit ?? EditCommand()).execute(command, out: out, err: err),
    'ffmpeg' => (ffmpeg ?? FfmpegCommand()).execute(command, out: out, err: err),
    _ => (render ?? RenderCommand()).execute(command, out: out, err: err),
  };
}

String _usage(ArgParser parser) =>
    '''
fluvie - headless renderer for Fluvie compositions.

Usage:
  fluvie init [--name <name>] [--dir <project>]
  fluvie preview <file.dart> [-d <device>]
  fluvie render <file.dart> --out <file> [options]
  fluvie render --spec <file.fluvie.json> --out <file> [options]
  fluvie generate "<prompt>" --out <file> [--provider <name>] [options]
  fluvie edit <file.fluvie.json> "<change>" --out <file> [options]
  fluvie list [--project <dir>]
  fluvie ffmpeg <install|path|status|uninstall>

A Fluvie project is a composition file, an `assets/` folder, and a pubspec.
`init` scaffolds one. `preview` runs it live with hot reload; `render` captures
it under `flutter test` and encodes it with ffmpeg. Both take the .dart file
directly and generate whatever they need, so there is no app or harness to
maintain. A composition file exposes a top-level `Video build()` (`--entry`
names another). `generate` authors a VideoSpec from a prompt with an LLM, writes
it, and renders it; `edit` refines an existing spec. `list` prints the render
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
