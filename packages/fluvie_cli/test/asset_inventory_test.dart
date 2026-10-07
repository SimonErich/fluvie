import 'dart:convert';
import 'dart:io';

import 'package:fluvie_cli/src/asset_inventory.dart';
import 'package:fluvie_cli/src/assets_command.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory project;
  setUp(() {
    project = Directory.systemTemp.createTempSync('fluvie_asset_facts_');
    File(p.join(project.path, 'pubspec.yaml')).writeAsStringSync('''
name: cat_story
flutter:
  fonts:
    - family: Cat Sans
      fonts:
        - asset: assets/fonts/Cat.ttf
''');
    Directory(p.join(project.path, 'assets', 'cat')).createSync(recursive: true);
    Directory(p.join(project.path, 'assets', 'fonts')).createSync();
  });
  tearDown(() => project.deleteSync(recursive: true));

  test('inventory preserves nested asset keys, bounded notes and authored font families', () async {
    final notes = File(p.join(project.path, 'assets', 'cat', 'story.txt'))
      ..writeAsStringSync('A long story');
    final font = File(p.join(project.path, 'assets', 'fonts', 'Cat.ttf'))..writeAsBytesSync([0]);
    final root = p.join(project.path, 'assets');
    final files = inventoryFiles(Directory(root));
    expect(files.map((f) => p.relative(f.path, from: root)), ['cat/story.txt', 'fonts/Cat.ttf']);
    final note = await inspectAsset(notes, root: root, project: project.path, textLimit: 6);
    expect(note['assetKey'], 'assets/cat/story.txt');
    expect(note['path'], 'cat/story.txt');
    expect(note['text'], {'preview': 'A long', 'truncated': true, 'previewByteLimit': 6});
    final family = await inspectAsset(font, root: root, project: project.path);
    expect((family['font']! as Map)['declaredFamilies'], ['Cat Sans']);
  });

  test('video facts preserve rotation, alpha and estimated frame-count accuracy', () async {
    final file = File(p.join(project.path, 'assets', 'cat', 'turn.webm'))..writeAsBytesSync([0]);
    final result = await inspectAsset(
      file,
      root: p.join(project.path, 'assets'),
      probe: (_) async => {
        'streams': <Object?>[
          <String, Object?>{
            'codec_type': 'video',
            'codec_name': 'vp9',
            'width': 640,
            'height': 360,
            'avg_frame_rate': '24/1',
            'duration': '2',
            'side_data_list': <Object?>[
              <String, Object?>{'rotation': -90},
            ],
            'tags': <String, Object?>{'alpha_mode': '1'},
          },
          <String, Object?>{'codec_type': 'audio', 'codec_name': 'opus'},
        ],
      },
    );
    expect(result['media'], containsPair('width', 360));
    expect(result['media'], containsPair('height', 640));
    expect(result['media'], containsPair('rotationDegrees', 270));
    expect(result['media'], containsPair('hasAlpha', true));
    expect(result['media'], containsPair('hasAudio', true));
    expect(result['media'], containsPair('frameCount', 48));
    expect(result['media'], containsPair('frameCountAccuracy', 'estimated'));
  });

  test('audio-only probes and still images do not need video timing', () async {
    final root = p.join(project.path, 'assets');
    final audio = File(p.join(root, 'music.mp3'))..writeAsBytesSync([0]);
    final photo = File(p.join(root, 'cat', 'sleep.png'))..writeAsBytesSync([0]);
    final audioResult = await inspectAsset(
      audio,
      root: root,
      probe: (_) async => {
        'streams': <Object?>[
          <String, Object?>{
            'codec_type': 'audio',
            'codec_name': 'mp3',
            'sample_rate': '48000',
            'channels': 2,
          },
        ],
        'format': <String, Object?>{'duration': '12.5'},
      },
    );
    expect(audioResult['media'], containsPair('durationSeconds', 12.5));
    expect(audioResult['media'], containsPair('sampleRate', 48000));
    final photoResult = await inspectAsset(
      photo,
      root: root,
      probe: (_) async => {
        'streams': <Object?>[
          <String, Object?>{
            'codec_type': 'video',
            'codec_name': 'png',
            'width': 80,
            'height': 60,
            'pix_fmt': 'rgba',
          },
        ],
      },
    );
    expect(photoResult['media'], containsPair('hasAlpha', true));
    expect(photoResult['media'], containsPair('durationSeconds', null));
  });

  test(
    'one broken media file retains its file facts and other assets in structured output',
    () async {
      final root = p.join(project.path, 'assets');
      File(p.join(root, 'cat', 'broken.mp4')).writeAsBytesSync([1, 2]);
      File(p.join(root, 'story.txt')).writeAsStringSync('Use this caption');
      final out = StringBuffer();
      final exit =
          await AssetsCommand(
            probe: (_) async => throw const FormatException('invalid media'),
          ).execute(
            AssetsCommand.buildParser().parse([root, '--json']),
            out: out,
            err: StringBuffer(),
          );
      final report = jsonDecode(out.toString()) as Map;
      final files = report['files'] as List;
      expect(exit, 1);
      expect(files, hasLength(2));
      expect(files.first, containsPair('assetKey', 'assets/cat/broken.mp4'));
      expect(files.first, containsPair('sizeBytes', 2));
      expect(files.last, containsPair('text', containsPair('preview', 'Use this caption')));
      expect(report['errors'], hasLength(1));
    },
  );

  test('missing probe tools still return every file without modifying the project', () async {
    final root = p.join(project.path, 'assets');
    File(p.join(root, 'cat', 'clip.mp4')).writeAsBytesSync([0]);
    File(p.join(root, 'story.txt')).writeAsStringSync('A story');
    final before = project.listSync(recursive: true).map((e) => e.path).toList()..sort();
    final out = StringBuffer();
    expect(
      await AssetsCommand(runner: const _MissingRunner()).execute(
        AssetsCommand.buildParser().parse([
          root,
          '--project',
          project.path,
          '--json',
        ]),
        out: out,
        err: StringBuffer(),
      ),
      1,
    );
    final report = jsonDecode(out.toString()) as Map;
    expect(report['files'], hasLength(2));
    expect((report['errors'] as List).single, contains('Media probe unavailable'));
    final after = project.listSync(recursive: true).map((e) => e.path).toList()..sort();
    expect(after, before);
  });
}

final class _MissingRunner implements ProcessRunner {
  const _MissingRunner();
  @override
  Future<ProcessRunResult> run(
    String executable,
    List<String> args, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async => throw ProcessException(executable, args, 'Not installed');
}
