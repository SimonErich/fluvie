import 'dart:io';

import 'package:fluvie_cli/fluvie_cli.dart';

Future<void> main(List<String> args) async {
  exitCode = await run(args, out: stdout, err: stderr);
}
