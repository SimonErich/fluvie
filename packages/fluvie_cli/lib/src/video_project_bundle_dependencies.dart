part of 'video_project_bundle.dart';

extension _BundleDependencies on _BundleInputs {
  Future<void> dependencies(String root) async {
    File? config;
    var ancestor = p.absolute(root);
    while (true) {
      final file = File(p.join(ancestor, '.dart_tool', 'package_config.json'));
      if (file.existsSync()) {
        config = file;
        break;
      }
      final parent = p.dirname(ancestor);
      if (parent == ancestor) break;
      ancestor = parent;
    }
    if (config == null) {
      throw const CliFailure('Resolve dependencies with flutter pub get before bundling.');
    }
    final lockFile = File(p.join(config.parent.parent.path, 'pubspec.lock'));
    if (!lockFile.existsSync()) {
      throw const CliFailure('A pinned pubspec.lock is required for replay.');
    }
    final lock = loadYaml(lockFile.readAsStringSync()) as YamlMap;
    final sources = lock['packages'] as YamlMap;
    final doc = jsonDecode(config.readAsStringSync()) as Map<String, Object?>;
    final roots = <String, String>{
      for (final entry in (doc['packages']! as List).cast<Map<String, Object?>>())
        entry['name']! as String: config.uri.resolve(entry['rootUri']! as String).toFilePath(),
    };
    final needed = <String>{};
    void visit(String path, {bool dev = false}) {
      final spec = loadYaml(File(p.join(path, 'pubspec.yaml')).readAsStringSync()) as YamlMap;
      for (final section in ['dependencies', if (dev) 'dev_dependencies']) {
        final deps = spec[section];
        if (deps is! YamlMap) continue;
        for (final name in deps.keys.cast<String>()) {
          if (needed.add(name) && roots[name] != null) visit(roots[name]!);
        }
      }
    }

    visit(root, dev: true);
    final vendor = <String>{};
    for (final name in needed) {
      final resolved = sources[name];
      if (resolved is YamlMap && {'path', 'git'}.contains(resolved['source'])) vendor.add(name);
    }
    for (final name in vendor) {
      final source = roots[name];
      if (source == null) throw CliFailure('Resolved dependency "$name" is missing.');
      for (final directory in [
        'lib',
        'bin',
        'hook',
        'android',
        'ios',
        'linux',
        'macos',
        'windows',
        'web',
        'assets',
      ]) {
        await tree(p.join(source, directory), 'vendor/$name/$directory');
      }
      for (final resource in projectResources(source)) {
        final path = p.normalize(p.join(source, resource));
        if (!p.isWithin(
          Directory(source).resolveSymbolicLinksSync(),
          FileSystemEntity.isDirectorySync(path)
              ? Directory(path).resolveSymbolicLinksSync()
              : File(path).resolveSymbolicLinksSync(),
        )) {
          throw const CliFailure('Dependency resource escapes its package.');
        }
        await tree(path, 'vendor/$name/$resource');
      }
      for (final file in ['pubspec.yaml', 'LICENSE', 'NOTICE']) {
        await tree(p.join(source, file), 'vendor/$name/$file');
      }
    }
    await tree(lockFile.path, 'project/pubspec.lock');
    await tree(lockFile.path, 'provenance/original-pubspec.lock');
    final replayLock = File(p.join(stage.path, 'project/pubspec.lock'));
    final lockEditor = YamlEditor(await replayLock.readAsString());
    for (final name in vendor) {
      final original = Map<String, Object?>.from(sources[name] as YamlMap);
      lockEditor.update(
        ['packages', name],
        {
          ...original,
          'source': 'path',
          'description': {'path': '../vendor/$name', 'relative': true},
        },
      );
    }
    await replayLock.writeAsString(lockEditor.toString());
    for (final name in [null, ...vendor]) {
      final file = File(
        p.join(stage.path, name == null ? 'project' : 'vendor/$name', 'pubspec.yaml'),
      );
      final editor = YamlEditor(await file.readAsString());
      final spec = editor.parseAt([]).value as YamlMap;
      final overrides = <String, Object?>{};
      if (name == null) {
        final original = spec['dependency_overrides'];
        if (original is YamlMap) overrides.addAll(Map<String, Object?>.from(original));
        final overrideFile = File(p.join(root, 'pubspec_overrides.yaml'));
        if (overrideFile.existsSync()) {
          final extra =
              (loadYaml(overrideFile.readAsStringSync()) as YamlMap)['dependency_overrides'];
          if (extra is YamlMap) overrides.addAll(Map<String, Object?>.from(extra));
        }
        overrides.removeWhere((key, _) => !needed.contains(key));
      }
      for (final key in ['resolution', 'workspace', 'dependency_overrides']) {
        if (spec.containsKey(key)) editor.remove([key]);
      }
      for (final section in ['dependencies', 'dev_dependencies']) {
        final deps = spec[section];
        if (deps is! YamlMap) continue;
        for (final dependency in vendor.intersection(deps.keys.cast<String>().toSet())) {
          editor.update(
            [section, dependency],
            {'path': '../${name == null ? 'vendor/' : ''}$dependency'},
          );
        }
      }
      if (name == null && (vendor.isNotEmpty || overrides.isNotEmpty)) {
        editor.update(
          ['dependency_overrides'],
          {
            ...overrides,
            for (final dependency in vendor) dependency: {'path': '../vendor/$dependency'},
          },
        );
      }
      await file.writeAsString(editor.toString());
    }
  }
}
