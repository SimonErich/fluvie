import 'dart:io';
import 'dart:math';

/// One staged capture harness: the generated [dir], the [harnessPath] to pass
/// `flutter test` (relative to the project root), and a [cleanup] that removes
/// it.
final class StagedHarness {
  /// Creates a staged harness.
  const StagedHarness({
    required this.projectDir,
    required this.dir,
    required this.harnessPath,
    required this.ephemeral,
  });

  /// The project root the render runs under (the working directory for `flutter
  /// test`); [harnessPath] is relative to it.
  final String projectDir;

  /// The directory holding the generated harness and any staged inputs.
  final Directory dir;

  /// The generated harness path, relative to [projectDir], for `flutter test`
  /// (which runs with the project as its working directory).
  final String harnessPath;

  /// Whether [cleanup] deletes [dir].
  final bool ephemeral;

  /// Deletes [dir] when the staging was [ephemeral]; a no-op otherwise, and a
  /// no-op if it is already gone.
  void cleanup() {
    if (!ephemeral) return;
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}

/// Writes [harnessSource] (plus any [extraFiles]) into `<projectDir>/<relativeDir>`
/// and returns what `flutter test` needs to run it.
///
/// The harness must live inside the project: `flutter test` resolves imports
/// against the project's package config, and it statically imports the
/// composition under render so the tester JIT-compiles it. That static import is
/// the only way to load arbitrary user code into a pre-built tester.
///
/// [ephemeral] staging gets a unique directory that [StagedHarness.cleanup]
/// deletes — what an untrusted Playground render needs, since two submissions
/// must never share a directory. A non-ephemeral staging reuses a deterministic
/// directory and survives the render, so `flutter test`'s kernel cache hits on a
/// re-render of the same target.
StagedHarness stageHarness({
  required String projectDir,
  required String harnessSource,
  required String relativeDir,
  Map<String, String> extraFiles = const {},
  bool ephemeral = true,
}) {
  final dir = Directory('$projectDir/$relativeDir')..createSync(recursive: true);
  File('${dir.path}/harness_test.dart').writeAsStringSync(harnessSource);
  for (final entry in extraFiles.entries) {
    File('${dir.path}/${entry.key}').writeAsStringSync(entry.value);
  }
  return StagedHarness(
    projectDir: projectDir,
    dir: dir,
    harnessPath: '$relativeDir/harness_test.dart',
    ephemeral: ephemeral,
  );
}

final _random = Random.secure();

/// A unique staging directory id, for a render whose directory must not collide
/// with a concurrent one.
String uniqueStageId() {
  final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final salt = _random.nextInt(1 << 32).toRadixString(36);
  return '$stamp$salt';
}
