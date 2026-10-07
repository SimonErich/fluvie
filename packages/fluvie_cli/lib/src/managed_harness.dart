import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fluvie_cli/src/file_target.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:fluvie_cli/src/render_support.dart';
import 'package:fluvie_cli/src/stage_harness.dart';
import 'package:fluvie_cli/src/templates/dart_edit_input_template.dart';
import 'package:fluvie_cli/src/templates/file_harness_template.dart';
import 'package:path/path.dart' as p;

/// Cache location for managed adapters, outside the author's project.
String managedRenderCacheRoot() {
  final env = Platform.environment;
  final base =
      env['XDG_CACHE_HOME'] ??
      (Platform.isWindows ? env['LOCALAPPDATA'] : null) ??
      p.join(env['HOME'] ?? Directory.systemTemp.path, '.cache');
  return p.join(base, 'fluvie', 'render');
}

/// Creates a minimal static adapter using the consumer's resolved dependencies.
/// Shared rendering behavior remains in the resolved Fluvie package.
Future<StagedHarness> stageManagedHarness({
  required String projectDir,
  required ProcessRunner runner,
  FileTarget? target,
  FileTarget? renderer,
  bool spec = false,
  bool author = false,
  bool dartEdit = false,
  bool worker = false,
  String? cacheRoot,
}) async {
  final config = await prepareRenderPackageConfig(
    projectDir: projectDir,
    runner: runner,
    author: author,
    cacheRoot: cacheRoot ?? managedRenderCacheRoot(),
  );
  final fingerprint = sha256
      .convert(
        utf8.encode(
          jsonEncode({
            'adapterVersion': 2,
            'project': p.normalize(p.absolute(projectDir)),
            'target': target?.externalImport,
            'entry': target?.entry,
            'renderer': renderer?.externalImport,
            'rendererEntry': renderer?.entry,
            'spec': spec,
            'author': author,
            'dartEdit': dartEdit,
            'worker': worker,
            'config': File(config).readAsStringSync(),
          }),
        ),
      )
      .toString();
  final dir = Directory(p.join(cacheRoot ?? managedRenderCacheRoot(), 'adapters', fingerprint))
    ..createSync(recursive: true);
  final lock = await File(p.join(dir.path, '.lock')).open(mode: FileMode.append);
  await lock.lock();
  try {
    if (spec || author) {
      _writeIfChanged(
        File(p.join(dir.path, 'input.dart')),
        dartEdit ? dartEditInputSource() : specInputSource(author: author),
      );
    }
    final source = fileHarnessSource(
      targetImport: target?.externalImport ?? 'input.dart',
      entry: target?.entry ?? 'build',
      rendererImport: renderer?.externalImport,
      rendererEntry: renderer?.entry ?? 'buildRenderer',
      asynchronous: spec || author,
      worker: worker,
    );
    _writeIfChanged(File(p.join(dir.path, 'harness_test.dart')), source);
  } finally {
    await lock.unlock();
    await lock.close();
  }
  return StagedHarness(
    projectDir: projectDir,
    dir: dir,
    harnessPath: p.join(dir.path, 'harness_test.dart'),
    ephemeral: false,
    packageConfigPath: config,
    sourceFiles: List.unmodifiable([?target?.path, ?renderer?.path]),
    generatedSourceDirectories: [cacheRoot ?? managedRenderCacheRoot()],
  );
}

void _writeIfChanged(File file, String source) {
  if (file.existsSync() && file.readAsStringSync() == source) return;
  file.writeAsStringSync(source);
}

/// Default output for a composition or spec, relative to the selected project.
String defaultRenderOutput(String projectDir, String name, {String? format}) {
  final slug = p.basename(name).replaceFirst(RegExp(r'\.fluvie\.json$|\.json$|\.dart$'), '');
  final extension = switch (format) {
    'gif' => 'gif',
    'transparent' => 'webm',
    'imageSequence' => null,
    _ => 'mp4',
  };
  return p.join(projectDir, 'build', 'fluvie', extension == null ? slug : '$slug.$extension');
}
