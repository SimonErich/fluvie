import 'dart:convert';
import 'dart:io';

import 'package:fluvie_cli/src/asset_catalog.dart';
import 'package:fluvie_cli/src/authoring_context.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'selected content-bound catalog supplies timed evidence without reading other prose',
    () async {
      final project = Directory.systemTemp.createTempSync('fluvie_author_evidence_');
      addTearDown(() => project.deleteSync(recursive: true));
      final assets = Directory('${project.path}/assets')..createSync();
      File('${assets.path}/cat.mp4').writeAsBytesSync([1, 2, 3]);
      final observations = File('${project.path}/observations.json')
        ..writeAsStringSync(
          jsonEncode([
            {
              'asset': 'cat.mp4',
              'text': 'Miso naps on the couch',
              'certainty': 'observed',
              'fromSeconds': 1,
            },
          ]),
        );
      final catalog = File('${project.path}/catalog.json')
        ..writeAsStringSync(
          jsonEncode(
            await buildAssetCatalog(
              root: assets,
              project: project.path,
              evidenceFile: observations.path,
            ),
          ),
        );
      final context = await buildAuthoringContext(
        projectDir: project.path,
        catalogPath: catalog.path,
      );
      expect(context, contains('Miso naps on the couch'));
      expect(context, contains('user_observation'));
      expect(context, contains('sha256'));
    },
  );
  test('relative selected notes and asset roots belong to the selected project', () async {
    final project = Directory.systemTemp.createTempSync('fluvie_author_context_relative_');
    addTearDown(() => project.deleteSync(recursive: true));
    final notes = File(p.join(project.path, 'story_assets/story.txt'))
      ..createSync(recursive: true)
      ..writeAsStringSync('Miso joined our family in 2020.');
    File(p.join(project.path, 'story_assets/nested/cat.mov'))
      ..createSync(recursive: true)
      ..writeAsBytesSync([1, 2, 3]);

    final context = await buildAuthoringContext(
      projectDir: project.path,
      contextFiles: ['story_assets/story.txt'],
      assetsDir: 'story_assets',
    );
    final report = jsonDecode(context.substring(context.indexOf('\n') + 1)) as Map<String, Object?>;
    expect(report['totalAssets'], 2);
    expect(
      (report['assets']! as List).first,
      containsPair('assetKey', 'story_assets/nested/cat.mov'),
    );
    expect((report['notes']! as List).single, containsPair('path', notes.path));
    expect(context, contains('Miso joined our family in 2020.'));
  });

  test(
    'sorted factual asset inventory excludes unselected story prose and bounds selected notes',
    () async {
      final project = Directory.systemTemp.createTempSync('fluvie_author_context_');
      addTearDown(() => project.deleteSync(recursive: true));
      File(p.join(project.path, 'assets/z_story.txt'))
        ..createSync(recursive: true)
        ..writeAsStringSync('UNSELECTED PRIVATE STORY');
      File(p.join(project.path, 'assets/a_cat.mov')).writeAsBytesSync([1, 2, 3]);
      final selected = File(p.join(project.path, 'notes.txt'))
        ..writeAsStringSync('EXPLICIT STORY ${'a' * 9000}');
      final context = await buildAuthoringContext(
        projectDir: project.path,
        contextFiles: [selected.path],
      );
      expect(context, isNot(contains('UNSELECTED PRIVATE STORY')));
      expect(context, contains('EXPLICIT STORY'));
      expect(context, isNot(contains('a' * 8193)));
      final report =
          jsonDecode(context.substring(context.indexOf('\n') + 1)) as Map<String, Object?>;
      expect((report['assets']! as List).first, containsPair('assetKey', 'assets/a_cat.mov'));
      expect((report['notes']! as List).single, containsPair('truncated', true));
      expect(utf8.encode(context).length, lessThanOrEqualTo(65536));
      expect(context, contains('do not infer visual content'));
    },
  );

  test(
    'oversized inventory reports omitted facts and missing explicit context fails clearly',
    () async {
      final project = Directory.systemTemp.createTempSync('fluvie_author_context_bound_');
      addTearDown(() => project.deleteSync(recursive: true));
      for (var i = 0; i < 105; i++) {
        File(p.join(project.path, 'assets/$i.txt'))
          ..createSync(recursive: true)
          ..writeAsStringSync('story');
      }
      final context = await buildAuthoringContext(projectDir: project.path);
      final report =
          jsonDecode(context.substring(context.indexOf('\n') + 1)) as Map<String, Object?>;
      expect((report['assets']! as List).length, 100);
      expect(report['omittedAssets'], 5);
      await expectLater(
        buildAuthoringContext(projectDir: project.path, contextFiles: ['/missing_story.txt']),
        throwsA(
          isA<CliFailure>().having(
            (error) => error.message,
            'message',
            contains('Context file not found'),
          ),
        ),
      );
    },
  );
}
