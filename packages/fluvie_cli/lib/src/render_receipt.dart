import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/output_verification.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:path/path.dart' as p;

part 'render_receipt_event.dart';

/// Retains the inputs, toolchain and output identity after sandbox cleanup.
///
/// Hashes the output as a stream so a long video never enters memory at once.
/// The receipt is written beside the artifact as `<name>.render.json`; callers
/// emit [renderArtifactEvent] as the compact final NDJSON `artifact` event.
/// A failed check writes `<name>.failed.render.json` and throws [CliFailure].
Future<Map<String, Object?>> writeRenderReceipt({
  required String outputPath,
  required String sourceFingerprint,
  required Map<String, Object?> inputs,
  required Map<String, Object?> toolchain,
  required Map<String, Object?> options,
  Map<String, Object?>? captureManifest,
  String? source,
  String? ffprobeBinary,
  String? ffmpegBinary,
  bool strictDecode = false,
  Future<void>? whenCancelled,
  ProcessRunner? runner,
  String? posterPath,
}) async {
  final output = File(p.absolute(outputPath));
  final stat = output.statSync();
  if (stat.type != FileSystemEntityType.file && stat.type != FileSystemEntityType.directory) {
    throw FileSystemException('Cannot record a missing render artifact.', output.path);
  }
  final Map<String, Object?> outputIdentity;
  Map<String, Object?>? verification;
  if (stat.type == FileSystemEntityType.directory) {
    final files =
        Directory(
            output.path,
          ).listSync(recursive: true, followLinks: false).whereType<File>().toList()
          ..sort((left, right) => left.path.compareTo(right.path));
    if (files.isEmpty) {
      throw CliFailure('The render artifact directory is empty: ${output.path}');
    }
    final entries = <Map<String, Object?>>[];
    var byteLength = 0;
    for (final file in files) {
      final size = file.lengthSync();
      byteLength += size;
      entries.add({
        'path': p.relative(file.path, from: output.path).replaceAll(p.separator, '/'),
        'byteLength': size,
        'sha256': (await sha256.bind(file.openRead()).first).toString(),
      });
    }
    outputIdentity = {
      'path': output.path,
      'kind': 'directory',
      'byteLength': byteLength,
      'sha256': sha256.convert(utf8.encode(jsonEncode(entries))).toString(),
      'files': entries,
    };
  } else {
    outputIdentity = await _fileIdentity(output);
  }
  if (ffprobeBinary != null) {
    final intent = captureManifest?['outputIntent'];
    verification = await verifyOutput(
      output.path,
      expected: intent is Map<String, Object?> ? intent : const {},
      ffprobeBinary: ffprobeBinary,
      ffmpegBinary: ffmpegBinary,
      runner: runner,
      strictDecode: strictDecode,
      whenCancelled: whenCancelled,
    );
    outputIdentity['media'] = verification['observed'];
    if (verification.containsKey('probe')) outputIdentity['probe'] = verification['probe'];
  }
  final poster = posterPath == null ? null : await _fileIdentity(File(p.absolute(posterPath)));
  final verified = verification?['ok'] != false;
  final receiptPath = p.join(
    p.dirname(output.path),
    '${p.basenameWithoutExtension(output.path)}${verified ? '' : '.failed'}.render.json',
  );
  final payload = <String, Object?>{
    'schemaVersion': 1,
    'event': verified ? 'artifact' : 'artifactFailure',
    'filePath': output.path,
    'receiptPath': receiptPath,
    'source': ?source,
    'sourceFingerprint': sourceFingerprint,
    'inputs': inputs,
    'toolchain': toolchain,
    'options': options,
    'output': outputIdentity,
    'verification': ?verification,
    'capture': ?captureManifest,
    'poster': ?poster,
  };
  final temporary = File('$receiptPath.$pid.tmp');
  try {
    await temporary.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(payload)}\n',
      flush: true,
    );
    // Windows does not replace an existing destination with File.rename.
    if (Platform.isWindows && File(receiptPath).existsSync()) await File(receiptPath).delete();
    await temporary.rename(receiptPath);
  } finally {
    if (temporary.existsSync()) await temporary.delete();
  }
  if (!verified) {
    final previous = File(
      p.join(p.dirname(output.path), '${p.basenameWithoutExtension(output.path)}.render.json'),
    );
    if (previous.existsSync()) await previous.delete();
    final mismatches = verification!['mismatches']! as List<Object?>;
    final first = mismatches.first! as Map<String, Object?>;
    final diagnostic = '${first['code']}: expected ${first['expected']}, got ${first['actual']}';
    final summary = diagnostic.length > 600 ? '${diagnostic.substring(0, 600)}…' : diagnostic;
    throw CliFailure(
      'The encoded output failed verification ($summary). '
      'Check the renderer output policy. Details: $receiptPath',
      code: 'output_verification_failed',
      details: {
        'receiptPath': receiptPath,
        'verification': {
          for (final key in ['ok', 'strictDecode', 'observed', 'mismatches'])
            key: verification[key],
        },
      },
    );
  }
  return payload;
}

Future<Map<String, Object?>> _fileIdentity(File file) async {
  if (!file.existsSync() || file.lengthSync() == 0) {
    throw CliFailure('The render artifact is missing or empty: ${file.path}');
  }
  return {
    'path': file.path,
    'byteLength': file.lengthSync(),
    'sha256': (await sha256.bind(file.openRead()).first).toString(),
  };
}
