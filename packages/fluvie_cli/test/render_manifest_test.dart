import 'dart:convert';
import 'dart:io';

import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/render_manifest.dart';
import 'package:test/test.dart';

Map<String, Object?> _demoJson({Object? schemaVersion = 1, List<Object?>? args}) => {
  'schemaVersion': schemaVersion,
  'width': 320,
  'height': 240,
  'fps': 30,
  'frameCount': 48,
  'framesFileName': 'frames.rgba',
  'outputFileName': 'out.mp4',
  'renderDigest': 'cbf29ce484222325',
  'ffmpegArgs': args ?? ['-f', 'rawvideo', '-i', 'frames.rgba', 'out.mp4'],
};

void main() {
  final sandbox = Directory('/tmp/fluvie_cli_manifest_sandbox');

  group('RenderManifest.fromJson', () {
    test('parses the fields the CLI needs', () {
      final manifest = RenderManifest.fromJson(_demoJson());

      expect(manifest.frameCount, 48);
      expect(manifest.framesFileName, 'frames.rgba');
      expect(manifest.outputFileName, 'out.mp4');
      expect(manifest.ffmpegArgs, ['-f', 'rawvideo', '-i', 'frames.rgba', 'out.mp4']);
    });

    test('rejects an unknown schemaVersion', () {
      expect(
        () => RenderManifest.fromJson(_demoJson(schemaVersion: 2)),
        throwsA(isA<CliFailure>().having((e) => e.message, 'message', contains('schemaVersion'))),
      );
    });

    test('rejects malformed field types', () {
      final json = _demoJson()..['frameCount'] = 'lots';
      expect(
        () => RenderManifest.fromJson(json),
        throwsA(isA<CliFailure>().having((e) => e.message, 'message', contains('Malformed'))),
      );
    });

    test('a no-poster manifest has null poster fields', () {
      final manifest = RenderManifest.fromJson(_demoJson());
      expect(manifest.posterArgs, isNull);
      expect(manifest.posterFileName, isNull);
    });

    test('parses the optional poster invocation', () {
      final json = _demoJson()
        ..['posterFileName'] = 'poster.png'
        ..['posterArgs'] = ['-i', 'frames.rgba', 'poster.png'];
      final manifest = RenderManifest.fromJson(json);
      expect(manifest.posterFileName, 'poster.png');
      expect(manifest.posterArgs, ['-i', 'frames.rgba', 'poster.png']);
    });

    test('rejects malformed poster args', () {
      final json = _demoJson()
        ..['posterFileName'] = 'poster.png'
        ..['posterArgs'] = [1, 2];
      expect(
        () => RenderManifest.fromJson(json),
        throwsA(isA<CliFailure>().having((e) => e.message, 'message', contains('Malformed'))),
      );
    });
  });

  group('RenderManifest.read', () {
    test('a missing manifest reports a capture failure', () {
      final empty = Directory.systemTemp.createTempSync('fluvie_cli_manifest_');
      addTearDown(() => empty.deleteSync(recursive: true));

      expect(
        () => RenderManifest.read(empty),
        throwsA(isA<CliFailure>().having((e) => e.message, 'message', contains('capture'))),
      );
    });

    test('reads and parses a written manifest', () {
      final dir = Directory.systemTemp.createTempSync('fluvie_cli_manifest_');
      addTearDown(() => dir.deleteSync(recursive: true));
      File('${dir.path}/manifest.json').writeAsStringSync(jsonEncode(_demoJson()));

      expect(RenderManifest.read(dir).frameCount, 48);
    });

    test('invalid JSON reports a manifest failure', () {
      final dir = Directory.systemTemp.createTempSync('fluvie_cli_manifest_');
      addTearDown(() => dir.deleteSync(recursive: true));
      File('${dir.path}/manifest.json').writeAsStringSync('{nope');

      expect(
        () => RenderManifest.read(dir),
        throwsA(isA<CliFailure>().having((e) => e.message, 'message', contains('JSON'))),
      );
    });

    test('a non-object JSON document reports a manifest failure', () {
      final dir = Directory.systemTemp.createTempSync('fluvie_cli_manifest_');
      addTearDown(() => dir.deleteSync(recursive: true));
      File('${dir.path}/manifest.json').writeAsStringSync('[1, 2]');

      expect(
        () => RenderManifest.read(dir),
        throwsA(isA<CliFailure>().having((e) => e.message, 'message', contains('object'))),
      );
    });
  });

  group('RenderManifest image-sequence detection', () {
    test('a single-file output is not an image sequence', () {
      final manifest = RenderManifest.fromJson(_demoJson());
      expect(manifest.isImageSequence, isFalse);
    });

    test('an image2 %0Nd pattern is an image sequence with literal bounds', () {
      final manifest = RenderManifest.fromJson(_demoJson()..['outputFileName'] = 'frame_%06d.png');
      expect(manifest.isImageSequence, isTrue);
      expect(manifest.imageSequenceBounds, (prefix: 'frame_', suffix: '.png'));
    });

    test('imageSequenceBounds throws for a non-pattern name', () {
      final manifest = RenderManifest.fromJson(_demoJson());
      expect(() => manifest.imageSequenceBounds, throwsA(isA<StateError>()));
    });

    test('the pattern passes sandbox confinement (the % is allowed)', () {
      final manifest = RenderManifest.fromJson(_demoJson()..['outputFileName'] = 'frame_%06d.png');
      expect(() => manifest.validateSandboxConfinement(sandbox), returnsNormally);
    });
  });

  group('RenderManifest.validateSandboxConfinement', () {
    test('accepts the sandbox-relative demo plan', () {
      final manifest = RenderManifest.fromJson(_demoJson());
      expect(() => manifest.validateSandboxConfinement(sandbox), returnsNormally);
    });

    test('rejects an absolute path token', () {
      final manifest = RenderManifest.fromJson(_demoJson(args: ['-i', '/etc/passwd', 'out.mp4']));
      expect(
        () => manifest.validateSandboxConfinement(sandbox),
        throwsA(isA<CliFailure>().having((e) => e.message, 'message', contains('/etc/passwd'))),
      );
    });

    test('rejects an escaping ../ token', () {
      final manifest = RenderManifest.fromJson(
        _demoJson(args: ['-i', 'frames.rgba', '../evil.mp4']),
      );
      expect(
        () => manifest.validateSandboxConfinement(sandbox),
        throwsA(isA<CliFailure>().having((e) => e.message, 'message', contains('../evil.mp4'))),
      );
    });

    test('rejects a Windows drive path token', () {
      final manifest = RenderManifest.fromJson(_demoJson(args: [r'C:\evil\out.mp4']));
      expect(() => manifest.validateSandboxConfinement(sandbox), throwsA(isA<CliFailure>()));
    });

    test('rejects file names with separators or a leading dash', () {
      for (final name in ['../frames.rgba', 'a/b.rgba', '-frames.rgba', '']) {
        final manifest = RenderManifest.fromJson(_demoJson()..['framesFileName'] = name);
        expect(
          () => manifest.validateSandboxConfinement(sandbox),
          throwsA(isA<CliFailure>()),
          reason: 'framesFileName "$name" must be rejected',
        );
      }
    });

    test('rejects ffmpeg protocol-URL tokens (file:, concat:, pipe:)', () {
      for (final token in ['file:///etc/passwd', 'concat:frames.rgba|/etc/shadow', 'pipe:1']) {
        final manifest = RenderManifest.fromJson(_demoJson(args: ['-i', token, 'out.mp4']));
        expect(
          () => manifest.validateSandboxConfinement(sandbox),
          throwsA(isA<CliFailure>().having((e) => e.message, 'message', contains(token))),
          reason: 'protocol token "$token" must be rejected',
        );
      }
    });

    test('keeps stream selectors and filter tokens (-map, 0:v:0, format=yuv420p)', () {
      final manifest = RenderManifest.fromJson(
        _demoJson(
          args: ['-map', '0:v:0', '-vf', 'format=pix_fmts=yuv420p,scale=w=320:h=240', 'out.mp4'],
        ),
      );
      expect(() => manifest.validateSandboxConfinement(sandbox), returnsNormally);
    });

    test('keeps flag-shaped tokens like -1 and +bitexact', () {
      final manifest = RenderManifest.fromJson(
        _demoJson(args: ['-map_metadata', '-1', '-fflags', '+bitexact', 'out.mp4']),
      );
      expect(() => manifest.validateSandboxConfinement(sandbox), returnsNormally);
    });
  });
}
