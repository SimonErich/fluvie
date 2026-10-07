import 'dart:convert';

import 'package:args/args.dart';
import 'package:fluvie_cli/docs.dart';

/// Offline documentation and compact context for coding agents.
final class DocsCommand {
  /// Creates the stateless command.
  const DocsCommand();

  /// Documentation output options.
  static ArgParser buildParser() => ArgParser()
    ..addFlag(
      'context',
      negatable: false,
      help: 'Print the bundled authoring context for a coding agent.',
    )
    ..addFlag('json', negatable: false, help: 'Emit machine-readable versioned documentation.');

  /// Lists pages, reads one page or prints authoring context.
  int execute(ArgResults args, {required StringSink out, required StringSink err}) {
    if (args.rest.length > 1 || args.flag('context') && args.rest.isNotEmpty) {
      err.writeln('Use `fluvie docs [page]` or `fluvie docs --context`.');
      return 64;
    }
    final Map<String, Object?> payload;
    final String body;
    if (args.flag('context')) {
      body = authoringContext();
      payload = {'context': body};
    } else if (args.rest.isEmpty) {
      payload = {
        'pages': [
          for (final page in bundledDocumentation) {'path': page.path, 'title': page.title},
        ],
      };
      body = bundledDocumentation.map((page) => '${page.path}\t${page.title}').join('\n');
    } else {
      final path = args.rest.single;
      final pages = bundledDocumentation
          .where((page) => page.path == path || page.path == '$path.md')
          .toList();
      if (pages.length != 1) {
        err.writeln('Unknown documentation page "$path". Run `fluvie docs` to list bundled pages.');
        return 64;
      }
      final page = pages.single;
      body = page.body;
      payload = {'path': page.path, 'title': page.title, 'body': body};
    }
    out.writeln(
      args.flag('json')
          ? jsonEncode({
              'version': documentationVersion,
              'digest': documentationDigest,
              ...payload,
            })
          : body,
    );
    return 0;
  }
}
