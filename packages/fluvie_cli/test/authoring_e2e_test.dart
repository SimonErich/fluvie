@Tags(['ffmpeg'])
@Timeout(Duration(minutes: 8))
library;

// Uses the existing SDK integration tag. This proof needs real Flutter, but no
// credentials or external model service. Includes source authoring, safe native
// edits, local visual evidence, and a verified three-frame real export.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('fresh source project authors and edits via real HTTP with explicit notes', () async {
    final root = p.normalize(p.join(Directory.current.path, '../..'));
    final project = await Directory.systemTemp.createTemp('fluvie_ai_e2e_');
    addTearDown(() => project.delete(recursive: true));
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final requests = <Map<String, Object?>>[];
    server.listen((request) async {
      final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map<String, Object?>;
      requests.add(body);
      final spec = {
        'fluvieSpec': 1,
        'size': 'square',
        'fps': 2,
        'scenes': [
          {
            'duration': '1s',
            'children': [
              {
                'type': 'Text',
                'text': requests.length == 1 ? 'Fixture story' : 'Edited fixture story',
                'textAlign': 'center',
                'transform': {'x': 0.5, 'y': 0.8, 'w': 0.8, 'anchor': 'center'},
                'style': {'fontSize': 64, 'color': '#ffffff'},
              },
            ],
          },
        ],
      };
      request.response
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'message': {
              'role': 'assistant',
              'content': jsonEncode(
                requests.length == 3
                    ? {
                        'edits': [
                          {'before': 'Fixture story', 'after': 'Dart edited fixture story'},
                        ],
                      }
                    : spec,
              ),
            },
            'done': true,
          }),
        );
      await request.response.close();
    });
    final environment = {
      'FLUVIE_AI_ENDPOINT': 'http://127.0.0.1:${server.port}/api/chat',
      'FLUVIE_AI_MODEL': 'fixture',
    };
    Future<String> run(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    }) async {
      final process = await Process.start(
        executable,
        arguments,
        workingDirectory: workingDirectory ?? project.path,
        environment: environment,
      );
      final stdout = process.stdout.transform(utf8.decoder).join();
      final stderr = process.stderr.transform(utf8.decoder).join();
      final int code;
      try {
        code = await process.exitCode.timeout(const Duration(minutes: 3));
      } on TimeoutException {
        process.kill(ProcessSignal.sigkill);
        throw TimeoutException(
          '$executable ${arguments.join(' ')}\n${await stdout}\n${await stderr}',
          const Duration(minutes: 3),
        );
      }
      final output = await stdout;
      final errors = await stderr;
      expect(code, 0, reason: '$executable ${arguments.join(' ')}\n$output\n$errors');
      return output;
    }

    final cli = [
      '--packages=${p.join(root, '.dart_tool/package_config.json')}',
      p.join(root, 'packages/fluvie_cli/bin/fluvie.dart'),
    ];
    await run('flutter', [
      'create',
      '--empty',
      '--platforms=web',
      '--project-name',
      'fluvie_ai_e2e',
      project.path,
    ]);
    await run('dart', [...cli, 'init', '--dir', project.path, '--fluvie-path', root, '--with-ai']);
    await run('flutter', ['pub', 'get']);
    final pubspec = File(p.join(project.path, 'pubspec.yaml')).readAsStringSync();
    final lock = File(p.join(project.path, 'pubspec.lock')).readAsStringSync();
    await File(
      p.join(project.path, 'assets/story.txt'),
    ).writeAsString('Explicit story fixture: my cat naps in the sunshine.');
    final generation = await run('dart', [
      ...cli,
      'generate',
      'Use the assets and selected notes',
      '--provider',
      'ollama',
      '--no-render',
      '--dart-out',
      'lib/generated.dart',
      '--context-file',
      'assets/story.txt',
      '--machine',
    ]);
    final specPath = p.join(project.path, 'build/fluvie/generated.fluvie.json');
    expect(File(specPath).existsSync(), isTrue);
    final editing = await run('dart', [
      ...cli,
      'edit',
      specPath,
      'Change the title',
      '--provider',
      'ollama',
      '--no-render',
      '--dart-out',
      'lib/edited.dart',
      '--context-file',
      'assets/story.txt',
      '--out',
      'build/fluvie/edited.mp4',
      '--machine',
    ]);
    await run('flutter', ['analyze', '--no-pub', 'lib/generated.dart', 'lib/edited.dart']);
    final generated = File(p.join(project.path, 'lib/generated.dart'));
    final originalDart = '${generated.readAsStringSync()}\n// Preserve my handwritten note.\n';
    await generated.writeAsString(originalDart);
    await run('dart', [
      ...cli,
      'edit',
      generated.path,
      'Change only the title',
      '--provider',
      'ollama',
      '--no-render',
      '--toolchain',
      'system',
      '--context-file',
      'assets/story.txt',
      '--machine',
    ], workingDirectory: root);
    expect(
      generated.readAsStringSync(),
      originalDart.replaceFirst('Fixture story', 'Dart edited fixture story'),
    );
    expect(File('${generated.path}.fluvie.bak').readAsStringSync(), originalDart);
    expect(requests, hasLength(3));
    await File(p.join(project.path, 'lib/review.dart')).writeAsString('''
import 'package:fluvie/fluvie.dart';
import 'package:flutter/widgets.dart' as flutter;
Video build() => Video(width: 64, height: 48, fps: 3, scenes: [
  Scene(duration: 1.seconds, children: [FrameBuilder((frame) => flutter.SizedBox.expand(
    child: flutter.ColoredBox(color: frame.frame == 0 ? const flutter.Color(0xffff0000) : const flutter.Color(0xff00ff00)),
  ))]),
]);
''');
    final review =
        jsonDecode(
              await run('dart', [
                ...cli,
                'review',
                'lib/review.dart',
                '--samples',
                '0,2',
                '--determinism',
                '--render',
                '--strict-decode',
                '--toolchain',
                'system',
                '--json',
              ]),
            )
            as Map<String, Object?>;
    expect(review['ok'], isTrue);
    expect(review['samples'], hasLength(2));
    expect(review['determinism'], containsPair('ok', true));
    final artifact = review['artifact']! as Map<String, Object?>;
    expect(artifact['verification'], containsPair('strictDecode', true));
    expect(artifact['verification'], containsPair('ok', true));
    final inspectionEvents = const LineSplitter()
        .convert(
          await run('dart', [
            ...cli,
            'inspect',
            'lib/review.dart',
            '--toolchain',
            'system',
            '--machine',
          ]),
        )
        .map((line) => jsonDecode(line) as Map<String, Object?>)
        .toList();
    expect(inspectionEvents.last, containsPair('event', 'inspection'));
    expect(inspectionEvents.last, containsPair('totalFrames', 3));
    final frameEvents = const LineSplitter()
        .convert(
          await run('dart', [
            ...cli,
            'frame',
            'lib/review.dart',
            '--frame',
            '1',
            '--toolchain',
            'system',
            '--machine',
          ]),
        )
        .map((line) => jsonDecode(line) as Map<String, Object?>)
        .toList();
    expect(frameEvents.last, containsPair('event', 'frame'));
    expect(frameEvents.last, containsPair('frame', 1));
    expect(File(frameEvents.last['filePath']! as String).readAsBytesSync().take(8), [
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
    ]);
    for (final color in ['red', 'green']) {
      await run('ffmpeg', [
        '-v',
        'error',
        '-f',
        'lavfi',
        '-i',
        'color=c=$color:s=64x48:r=3:d=1',
        '-c:v',
        'libx264',
        '-pix_fmt',
        'yuv420p',
        p.join(project.path, 'assets/$color.mp4'),
      ]);
    }
    await File(
      p.join(project.path, 'assets/captions.srt'),
    ).writeAsString('1\n00:00:00,000 --> 00:00:00,500\nA cat naps.\n');
    final catalogPath = p.join(project.path, 'build/catalog.json');
    await run('dart', [
      ...cli,
      'assets',
      '--contact-sheets',
      '--catalog-out',
      catalogPath,
      '--transcript',
      'red.mp4=captions.srt',
      '--toolchain',
      'system',
      '--json',
    ]);
    final catalog = jsonDecode(await File(catalogPath).readAsString()) as Map<String, Object?>;
    final clips = (catalog['assets']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .where((asset) => asset['kind'] == 'video')
        .toList();
    expect(clips, hasLength(2));
    for (final clip in clips) {
      final sheet = clip['contactSheet']! as Map<String, Object?>;
      expect(sheet['sourceHash'], clip['sha256']);
      expect(sheet['cells'], isNotEmpty);
      expect(File(sheet['filePath']! as String).existsSync(), isTrue);
    }
    await run('dart', [
      ...cli,
      'generate',
      'Use the selected visual evidence',
      '--provider',
      'ollama',
      '--no-render',
      '--dart-out',
      'lib/evidence.dart',
      '--catalog',
      catalogPath,
      '--toolchain',
      'system',
      '--image-evidence',
      '--context-file',
      'assets/story.txt',
      '--machine',
    ]);
    expect(requests, hasLength(4));
    final evidenceTurns = (requests.last['messages']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(evidenceTurns.expand((turn) => (turn['images'] as List<Object?>?) ?? []), hasLength(2));
    expect(jsonEncode(requests.last), contains('A cat naps.'));
    expect(File(p.join(project.path, 'lib/evidence.dart')).existsSync(), isTrue);
    for (final request in requests) {
      expect(jsonEncode(request), contains('Explicit story fixture'));
    }
    for (final line
        in const LineSplitter()
            .convert('$generation\n$editing')
            .where((line) => line.trim().isNotEmpty)) {
      expect(jsonDecode(line), isA<Map<String, Object?>>());
    }
    expect(
      File(p.join(project.path, 'lib/edited.dart')).readAsStringSync(),
      contains('Edited fixture story'),
    );
    expect(File(p.join(project.path, 'build/fluvie/edited.mp4')).existsSync(), isFalse);
    expect(File(p.join(project.path, 'pubspec.yaml')).readAsStringSync(), pubspec);
    expect(File(p.join(project.path, 'pubspec.lock')).readAsStringSync(), lock);
    expect(Directory(p.join(project.path, '.fluvie')).existsSync(), isFalse);
  });
}
