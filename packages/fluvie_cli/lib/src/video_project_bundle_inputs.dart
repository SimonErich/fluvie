part of 'video_project_bundle.dart';

final class _BundleInputs {
  _BundleInputs(this.stage, {required this.maxBytes, required this.maxFiles});
  final Directory stage;
  final int maxBytes;
  final int maxFiles;
  final _copied = <String, String>{};
  int bytes = 0;
  int files = 0;
  static const excluded = {'.git', '.dart_tool', '.fluvie', '.codegraph', 'build', 'node_modules'};

  Future<void> tree(String source, String target, {bool dartOnly = false}) async {
    final type = FileSystemEntity.typeSync(source, followLinks: false);
    if (type == FileSystemEntityType.link) {
      throw CliFailure('Bundle inputs cannot be symlinks: $source');
    }
    if (type == FileSystemEntityType.directory) {
      for (final child in Directory(source).listSync(followLinks: false)) {
        final name = p.basename(child.path);
        if (!excluded.contains(name) && !name.startsWith('.')) {
          await tree(child.path, '$target/$name', dartOnly: dartOnly);
        }
      }
    } else if (type == FileSystemEntityType.file && (!dartOnly || source.endsWith('.dart'))) {
      final key = p.posix.normalize(target).toLowerCase();
      final original = _copied[key];
      if (original != null) {
        if (p.absolute(original) != p.absolute(source)) {
          throw const CliFailure('Bundle inputs collide at one portable file path.');
        }
        return;
      }
      _copied[key] = source;
      final file = File(source);
      bytes += file.lengthSync();
      files++;
      if (bytes > maxBytes || files > maxFiles) {
        throw const CliFailure('Video bundle exceeds its size or file-count budget.');
      }
      final output = File(p.join(stage.path, target));
      await output.parent.create(recursive: true);
      await file.copy(output.path);
    }
  }

  Future<void> project(String root) async {
    await tree(root, 'project', dartOnly: true);
    await tree(p.join(root, 'assets'), 'project/assets');
    for (final resource in projectResources(root)) {
      final source = p.normalize(p.join(root, resource));
      if (!p.isWithin(
        Directory(root).resolveSymbolicLinksSync(),
        FileSystemEntity.isDirectorySync(source)
            ? Directory(source).resolveSymbolicLinksSync()
            : File(source).resolveSymbolicLinksSync(),
      )) {
        throw const CliFailure('A declared resource escapes its project.');
      }
      if (!FileSystemEntity.isFileSync(source) && !FileSystemEntity.isDirectorySync(source)) {
        throw CliFailure('Declared bundle resource is missing: $resource');
      }
      await tree(source, 'project/$resource');
    }
    await tree(p.join(root, 'pubspec.yaml'), 'project/pubspec.yaml');
    await tree(p.join(root, 'pubspec.lock'), 'project/pubspec.lock');
    await tree(p.join(root, 'pubspec.yaml'), 'provenance/original-pubspec.yaml');
    await tree(p.join(root, 'pubspec_overrides.yaml'), 'provenance/original-overrides.yaml');
  }
}
