import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:path/path.dart' as p;

/// Reads explicitly selected observations, grouped by exact relative asset path.
Future<Map<String, List<Map<String, Object?>>>> readAssetObservations({
  required String root,
  required Set<String> assetPaths,
  String? evidenceFile,
  List<String> transcripts = const [],
}) async {
  final result = <String, List<Map<String, Object?>>>{};
  void add(String asset, Map<String, Object?> observation) {
    final normalized = p.url.joinAll(p.split(p.normalize(asset)));
    if (!assetPaths.contains(normalized)) throw CliFailure('Evidence asset not found: "$asset".');
    final from = observation['fromSeconds'];
    final to = observation['toSeconds'];
    if (from is! num ||
        !from.isFinite ||
        from < 0 ||
        (to != null && (to is! num || !to.isFinite || to <= from))) {
      throw const CliFailure('Evidence times must be finite, non-negative, and increasing.');
    }
    if (!{'observed', 'inferred', 'unknown'}.contains(observation['certainty'])) {
      throw const CliFailure('Evidence certainty must be observed, inferred, or unknown.');
    }
    final text = observation['text'];
    if (text is! String || text.trim().isEmpty || utf8.encode(text).length > 8192) {
      throw const CliFailure('Evidence text must contain 1..8192 bytes.');
    }
    result.putIfAbsent(normalized, () => []).add(observation);
  }

  if (evidenceFile != null) {
    final file = File(p.isAbsolute(evidenceFile) ? evidenceFile : p.join(root, evidenceFile));
    final bytes = await _readBounded(file);
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! List<Object?> || decoded.length > 1000) {
      throw const CliFailure('Evidence must be a JSON array of up to 1000 observations.');
    }
    for (final record in decoded) {
      if (record is! Map<String, Object?> || record['asset'] is! String) {
        throw const CliFailure('Each evidence record must name its asset.');
      }
      add(record['asset']! as String, {
        'fromSeconds': record['fromSeconds'] ?? 0,
        'toSeconds': record['toSeconds'],
        'text': record['text'],
        'certainty': record['certainty'],
        'provenance': {
          'kind': 'user_observation',
          'filePath': file.absolute.path,
          'sha256': sha256.convert(bytes).toString(),
        },
      });
    }
  }
  if (transcripts.length > 16) throw const CliFailure('Select at most 16 transcript files.');
  for (final input in transcripts) {
    final separator = input.indexOf('=');
    if (separator <= 0 || separator == input.length - 1) {
      throw const CliFailure('Use --transcript <asset-relative-path>=<captions.srt|vtt>.');
    }
    final asset = input.substring(0, separator);
    final path = input.substring(separator + 1);
    final file = File(p.isAbsolute(path) ? path : p.join(root, path));
    final bytes = await _readBounded(file);
    final provenance = {
      'kind': 'user_transcript',
      'filePath': file.absolute.path,
      'sha256': sha256.convert(bytes).toString(),
    };
    final cues = parseTranscript(utf8.decode(bytes));
    if (cues.isEmpty) throw CliFailure('No timestamped transcript cues in "${file.path}".');
    for (final cue in cues) {
      add(asset, {...cue, 'certainty': 'observed', 'provenance': provenance});
    }
  }
  return result;
}

Future<List<int>> _readBounded(File file) async {
  if (await file.length() > 256 * 1024) {
    throw CliFailure('Evidence exceeds 256 KiB: "${file.path}".');
  }
  return file.readAsBytes();
}

/// Parses SRT or WebVTT text into source-second ranges. Cue IDs and WebVTT
/// settings are ignored; subtitle lines remain intact as the transcript text.
List<Map<String, Object?>> parseTranscript(String source) {
  final cues = <Map<String, Object?>>[];
  final timing = RegExp(
    r'^((?:\d+:)?\d{2}:\d{2}[.,]\d{3})\s+-->\s+((?:\d+:)?\d{2}:\d{2}[.,]\d{3})(?:\s.*)?$',
  );
  for (final block in source.replaceAll('\r\n', '\n').split(RegExp(r'\n\s*\n'))) {
    final lines = block.trim().split('\n');
    final index = lines.indexWhere((line) => timing.hasMatch(line.trim()));
    if (index < 0) continue;
    final match = timing.firstMatch(lines[index].trim())!;
    final from = _timestamp(match.group(1)!);
    final to = _timestamp(match.group(2)!);
    if (to <= from) throw const CliFailure('Transcript cue end must follow its start.');
    cues.add({
      'fromSeconds': from,
      'toSeconds': to,
      'text': lines.skip(index + 1).join('\n').trim(),
    });
  }
  return cues;
}

double _timestamp(String value) {
  final fields = value.replaceAll(',', '.').split(':').map(double.parse).toList();
  if (fields[fields.length - 2] >= 60 || fields.last >= 60) {
    throw CliFailure(
      'Invalid transcript timestamp: "$value". Minutes and seconds must be below 60.',
    );
  }
  return fields.fold<double>(0, (time, part) => time * 60 + part);
}
