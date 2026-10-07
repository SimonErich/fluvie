import 'dart:convert';
import 'dart:io';

import 'package:fluvie_cli/src/asset_catalog.dart';
import 'package:fluvie_cli/src/asset_observations.dart';
import 'package:fluvie_cli/src/assets_command.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/ffmpeg_gate.dart';
import 'package:test/test.dart';

void main() {
  test('transcript parser rejects invalid clock fields and reversed cue timing', () {
    for (final input in [
      '00:61:01,000 --> 00:62:02,000\nA cat naps.',
      '00:01:61,000 --> 00:02:62,000\nA cat naps.',
      '00:00:02,000 --> 00:00:01,000\nA cat naps.',
    ]) {
      expect(() => parseTranscript(input), throwsA(isA<CliFailure>()));
    }
  });

  test('generated evidence directories are excluded when catalogs live inside assets', () async {
    final directory = Directory.systemTemp.createTempSync('fluvie_catalog_excluded_');
    addTearDown(() => directory.deleteSync(recursive: true));
    File('${directory.path}/story.txt').writeAsStringSync('My cat story');
    File('${directory.path}/asset_evidence/generated.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync([1]);
    final report = await buildAssetCatalog(
      root: directory,
      project: directory.path,
      excludedDirectories: {'${directory.path}/asset_evidence'},
    );
    expect(report['assets'], hasLength(1));
    expect((report['assets']! as List<Object?>).single, containsPair('path', 'story.txt'));
  });

  test('catalog ties explicit observations and timed transcripts to asset content', () async {
    final dir = Directory.systemTemp.createTempSync('fluvie_catalog_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/cat.mp4').writeAsBytesSync([1, 2, 3]);
    File(
      '${dir.path}/captions.vtt',
    ).writeAsStringSync('WEBVTT\n\n00:00:01.000 --> 00:00:02.500\nA cat naps.\n');
    final evidence = File('${dir.path}/observations.json')
      ..writeAsStringSync(
        jsonEncode([
          {
            'asset': 'cat.mp4',
            'fromSeconds': 1.0,
            'toSeconds': 2.5,
            'text': 'Miso is on the couch',
            'certainty': 'observed',
          },
        ]),
      );
    final report = await buildAssetCatalog(
      root: Directory(dir.path),
      project: dir.path,
      evidenceFile: evidence.path,
      transcripts: ['cat.mp4=captions.vtt'],
    );
    final assets = report['assets']! as List<Object?>;
    final cat = assets.cast<Map<String, Object?>>().singleWhere(
      (asset) => asset['path'] == 'cat.mp4',
    );
    expect(cat['sha256'], '039058c6f2c0cb492c533b0a4d14ef77cc0f78abccced5287d84a1a2011cfb81');
    final observations = cat['observations']! as List<Object?>;
    expect(observations, hasLength(2));
    expect(observations.first, containsPair('certainty', 'observed'));
    final transcript = observations.last! as Map<String, Object?>;
    expect(transcript['fromSeconds'], 1.0);
    expect(transcript['toSeconds'], 2.5);
    expect(transcript['text'], 'A cat naps.');
    expect(transcript['provenance'], containsPair('kind', 'user_transcript'));
  });

  test('changed media invalidates retained semantic evidence', () async {
    final dir = Directory.systemTemp.createTempSync('fluvie_catalog_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/cat.mp4')..writeAsBytesSync([1, 2, 3]);
    final catalog = File('${dir.path}/catalog.json');
    await catalog.writeAsString(jsonEncode(await buildAssetCatalog(root: dir, project: dir.path)));
    await file.writeAsBytes([4, 5, 6]);
    await expectLater(readAssetCatalog(catalog.path), throwsA(isA<CliFailure>()));
  });

  test('rejects unbound, invalid timestamps and undocumented certainty', () async {
    final dir = Directory.systemTemp.createTempSync('fluvie_catalog_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/cat.mp4').writeAsBytesSync([1]);
    final evidence = File('${dir.path}/evidence.json');
    for (final invalid in [
      {'asset': '../unknown.mp4', 'text': 'cat', 'certainty': 'observed'},
      {'asset': 'cat.mp4', 'text': 'cat', 'certainty': 'certain'},
      {'asset': 'cat.mp4', 'text': 'cat', 'certainty': 'observed', 'fromSeconds': -1},
      {
        'asset': 'cat.mp4',
        'text': 'cat',
        'certainty': 'observed',
        'fromSeconds': 2,
        'toSeconds': 1,
      },
    ]) {
      evidence.writeAsStringSync(jsonEncode([invalid]));
      await expectLater(
        buildAssetCatalog(root: dir, project: dir.path, evidenceFile: evidence.path),
        throwsA(isA<CliFailure>()),
      );
    }
  });

  test('assets command writes a selected catalog without calling a provider', () async {
    final project = Directory.systemTemp.createTempSync('fluvie_catalog_project_');
    addTearDown(() => project.deleteSync(recursive: true));
    File('${project.path}/pubspec.yaml').writeAsStringSync('name: cat\n');
    File('${project.path}/assets/story.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync('Selected story');
    final out = StringBuffer();
    final err = StringBuffer();
    final catalog = '${project.path}/build/catalog.json';
    final code = await AssetsCommand().execute(
      AssetsCommand.buildParser().parse([
        '--project',
        project.path,
        '--catalog-out',
        catalog,
        '--json',
      ]),
      out: out,
      err: err,
    );
    expect(code, 0, reason: err.toString());
    expect(await readAssetCatalog(catalog), containsPair('kind', 'asset_catalog'));
    expect(jsonDecode(out.toString()), containsPair('catalogPath', catalog));
  });

  test('explicit contact-sheet preparation automatically provisions its paired tools', () async {
    final project = Directory.systemTemp.createTempSync('fluvie_catalog_tools_');
    addTearDown(() => project.deleteSync(recursive: true));
    File('${project.path}/pubspec.yaml').writeAsStringSync('name: cat\n');
    Directory('${project.path}/assets').createSync();
    bool? download;
    final command = AssetsCommand(
      resolveToolchain:
          (
            runner, {
            binary,
            probeBinary,
            mode = 'managed',
            allowDownload = true,
            log = print,
          }) async {
            download = allowDownload;
            return const FfmpegToolchain(
              ffmpegPath: 'unused',
              ffprobePath: 'unused',
              build: 'test',
              ffmpegVersion: 'test',
              ffprobeVersion: 'test',
            );
          },
    );
    expect(
      await command.execute(
        AssetsCommand.buildParser().parse(['--project', project.path, '--contact-sheets']),
        out: StringBuffer(),
        err: StringBuffer(),
      ),
      0,
    );
    expect(download, isTrue);
  });
}
