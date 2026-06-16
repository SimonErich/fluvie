import 'package:args/args.dart';
import 'package:fluvie_cli/src/edit_command.dart';
import 'package:fluvie_cli/src/generate_command.dart';
import 'package:fluvie_cli/src/list_command.dart';
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
}) async {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this usage.')
    ..addCommand('render', RenderCommand.buildParser())
    ..addCommand('generate', GenerateCommand.buildParser())
    ..addCommand('edit', EditCommand.buildParser())
    ..addCommand('list', ListCommand.buildParser());

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
    'list' => (list ?? ListCommand()).execute(command, out: out, err: err),
    'generate' => (generate ?? GenerateCommand()).execute(command, out: out, err: err),
    'edit' => (edit ?? EditCommand()).execute(command, out: out, err: err),
    _ => (render ?? RenderCommand()).execute(command, out: out, err: err),
  };
}

String _usage(ArgParser parser) =>
    '''
fluvie - headless renderer for Fluvie compositions.

Usage:
  fluvie render <key> --out <file> [options]
  fluvie render --spec <file.fluvie.json> --out <file> [options]
  fluvie generate "<prompt>" --out <file> [--provider <name>] [options]
  fluvie edit <file.fluvie.json> "<change>" --out <file> [options]
  fluvie list [--project <dir>]

`render` captures the registered composition <key> (or a --spec VideoSpec
document) under `flutter test`, then encodes it with ffmpeg. `generate` authors
a VideoSpec from a prompt with an LLM, writes it, and renders it; `edit` refines
an existing spec. `list` prints every render key.

Render options:
${RenderCommand.buildParser().usage}

Generate options:
${GenerateCommand.buildParser().usage}

List options:
${ListCommand.buildParser().usage}

Global options:
${parser.usage}''';
