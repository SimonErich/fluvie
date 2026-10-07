import 'package:test/test.dart';

import '../src/workspace_inventory.dart';

void main() {
  const root = '''
workspace:
  - packages/fluvie_media
  - packages/future_package
  - apps/slides
  - examples/gallery
''';
  const manifests = {
    'packages/fluvie_media': 'name: fluvie_media\n',
    'packages/future_package': 'name: future_package\n',
    'apps/slides': 'name: slides\npublish_to: none\ndependencies:\n  flutter:\n    sdk: flutter\n',
    'examples/gallery':
        'name: gallery\npublish_to: none\ndev_dependencies:\n  flutter_test:\n    sdk: flutter\n',
  };
  const files = [
    'packages/fluvie_media/lib/native.dart',
    'packages/fluvie_media/test/native_test.dart',
    'packages/future_package/lib/api.dart',
    'packages/future_package/test/api_test.dart',
    'apps/slides/lib/main.dart',
    'apps/slides/test/main_test.dart',
    'examples/gallery/lib/main.dart',
    'examples/gallery/test/main_test.dart',
  ];

  test('new production packages enter every applicable gate without a target list', () {
    final inventory = WorkspaceInventory.parse(root, manifests: manifests, files: files);
    expect(inventory.problems, isEmpty);
    expect(inventory.analysisPaths, [
      'apps/slides',
      'examples/gallery',
      'packages/fluvie_media',
      'packages/future_package',
    ]);
    expect(inventory.testPaths, inventory.analysisPaths);
    expect(inventory.coveragePaths, [
      'apps/slides',
      'packages/fluvie_media',
      'packages/future_package',
    ]);
    expect(inventory.publishableNames, ['fluvie_media', 'future_package']);
    expect(inventory.dartdocPaths, ['packages/fluvie_media', 'packages/future_package']);
    expect(inventory.targets.where((target) => target.flutter).map((target) => target.path), [
      'apps/slides',
      'examples/gallery',
    ]);
  });

  test('a production manifest omitted from workspace cannot silently evade gates', () {
    final inventory = WorkspaceInventory.parse(
      root,
      manifests: {
        ...manifests,
        'packages/forgotten': 'name: forgotten\n',
      },
      files: files,
    );
    expect(inventory.problems, contains(contains('packages/forgotten')));
  });

  test('private production libraries receive API docs without becoming publishable', () {
    const path = 'packages/private_widgets';
    final inventory = WorkspaceInventory.parse(
      '$root  - $path\n',
      manifests: {...manifests, path: 'name: private_widgets\npublish_to: none\n'},
      files: [...files, '$path/lib/widgets.dart', '$path/test/widgets_test.dart'],
    );
    expect(inventory.problems, isEmpty);
    expect(inventory.dartdocPaths, contains(path));
    expect(inventory.dartdocPaths, isNot(contains('apps/slides')));
    expect(inventory.dartdocPaths, isNot(contains('examples/gallery')));
    expect(inventory.publishableNames, isNot(contains('private_widgets')));
  });

  test('declared missing manifests and untested production sources fail inventory', () {
    final inventory = WorkspaceInventory.parse(
      root,
      manifests: {
        ...manifests,
      }..remove('packages/future_package'),
      files: files.where((file) => !file.endsWith('native_test.dart')),
    );
    expect(inventory.problems, contains(contains('packages/future_package')));
    expect(inventory.problems, contains(contains('fluvie_media')));
  });

  test('workspace escapes and duplicate names fail with actionable evidence', () {
    final inventory = WorkspaceInventory.parse(
      'workspace:\n  - ../escape\n  - packages/a\n  - packages/b\n',
      manifests: {'packages/a': 'name: duplicate\n', 'packages/b': 'name: duplicate\n'},
      files: const [],
    );
    expect(inventory.problems, contains(contains('../escape')));
    expect(inventory.problems, contains(contains('duplicate')));
  });

  test('JSON records selection policy and coverage files from the same inventory', () {
    final inventory = WorkspaceInventory.parse(root, manifests: manifests, files: files);
    final json = inventory.toJson();
    expect(json['schemaVersion'], 1);
    expect(json['coveragePaths'], inventory.coveragePaths);
    expect(
      inventory.coverageFiles,
      inventory.coveragePaths.map((path) => '$path/coverage/lcov.info'),
    );
    expect(json['coveragePolicy'], contains('packages'));
  });
}
