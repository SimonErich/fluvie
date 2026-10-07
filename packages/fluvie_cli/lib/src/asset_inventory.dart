import 'dart:convert';
import 'dart:io';

import 'package:fluvie_cli/src/project_inspection.dart';
import 'package:fluvie_media/native.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Reads original ffprobe facts; no semantic model participates in inventory.
typedef AssetProbe = Future<Map<String, Object?>> Function(String path);

/// Stable, recursive file discovery; does not follow linked directories.
List<File> inventoryFiles(Directory root) =>
    root.listSync(recursive: true, followLinks: false).whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));

/// File category inferred only from its extension.
String assetKind(String path) {
  final extension = p.extension(path).toLowerCase();
  if (const {'.mp4', '.mov', '.webm', '.mkv', '.m4v', '.avi', '.mxf'}.contains(extension)) {
    return 'video';
  }
  if (const {
    '.mp3',
    '.wav',
    '.m4a',
    '.flac',
    '.ogg',
    '.aac',
    '.aiff',
    '.opus',
  }.contains(extension)) {
    return 'audio';
  }
  if (const {
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.webp',
    '.heic',
    '.avif',
    '.bmp',
    '.tiff',
    '.svg',
  }.contains(extension)) {
    return 'image';
  }
  if (const {'.ttf', '.otf', '.woff', '.woff2'}.contains(extension)) {
    return 'font';
  }
  if (const {
    '.txt',
    '.md',
    '.json',
    '.csv',
    '.srt',
    '.vtt',
    '.yaml',
    '.yml',
    '.toml',
  }.contains(extension)) {
    return 'text';
  }
  return 'other';
}

/// Whether ffprobe can inspect this kind of local asset.
bool needsAssetProbe(File file) =>
    const {'video', 'audio', 'image'}.contains(assetKind(file.path)) &&
    p.extension(file.path).toLowerCase() != '.svg';

/// Builds factual metadata for one file, with bounded text reads.
Future<Map<String, Object?>> inspectAsset(
  File file, {
  required String root,
  String? project,
  AssetProbe? probe,
  int textLimit = 8192,
}) async {
  final path = p.normalize(file.absolute.path);
  final stat = file.statSync();
  final kind = assetKind(path);
  final facts = <String, Object?>{
    'path': p.url.joinAll(p.split(p.relative(path, from: root))),
    'absolutePath': path,
    'assetKey': project != null && p.isWithin(project, path)
        ? p.url.joinAll(p.split(p.relative(path, from: project)))
        : null,
    'kind': kind,
    'sizeBytes': stat.size,
    'modifiedUtc': stat.modified.toUtc().toIso8601String(),
  };
  if (kind == 'text') facts['text'] = await _readText(file, textLimit);
  if (kind == 'font') {
    facts['font'] = {
      'fileName': p.basename(path),
      'declaredFamilies': _fontFamilies(path, project),
    };
  }
  if (probe != null && needsAssetProbe(file)) {
    final report = await probe(path);
    facts['probe'] = report;
    facts['media'] = _mediaFacts(report, kind);
  }
  return facts;
}

Future<Map<String, Object?>> _readText(File file, int limit) async {
  final handle = await file.open();
  try {
    final bytes = await handle.read(limit + 1);
    return {
      'preview': utf8.decode(bytes.take(limit).toList(), allowMalformed: true),
      'truncated': bytes.length > limit,
      'previewByteLimit': limit,
    };
  } finally {
    await handle.close();
  }
}

List<String> _fontFamilies(String path, String? project) {
  if (project == null) return const [];
  final flutter = readProjectPubspec(project)['flutter'];
  final fonts = flutter is YamlMap ? flutter['fonts'] : null;
  if (fonts is! YamlList) return const [];
  return [
    for (final family in fonts.whereType<YamlMap>())
      if (family['family'] is String && family['fonts'] is YamlList)
        for (final asset in (family['fonts'] as YamlList).whereType<YamlMap>())
          if (asset['asset'] is String &&
              p.normalize(p.join(project, asset['asset']! as String)) == path)
            family['family']! as String,
  ];
}

Map<String, Object?> _mediaFacts(Map<String, Object?> report, String kind) {
  final streams = (report['streams'] as List<Object?>? ?? [])
      .whereType<Map<String, Object?>>()
      .toList();
  if (kind == 'video') {
    final info = MediaSourceInfo.fromReport(report);
    final video = streams.firstWhere((stream) => stream['codec_type'] == 'video');
    return {
      ...info.toJson(),
      'frameCountAccuracy': int.tryParse('${video['nb_frames']}') == null
          ? 'estimated'
          : 'declared',
    };
  }
  final stream = streams.firstWhere(
    (value) => value['codec_type'] == (kind == 'audio' ? 'audio' : 'video'),
    orElse: () => {},
  );
  final format = report['format'];
  return {
    'codec': stream['codec_name'],
    'durationSeconds': double.tryParse(
      '${stream['duration'] ?? (format is Map<String, Object?> ? format['duration'] : null)}',
    ),
    'hasAudio': streams.any((value) => value['codec_type'] == 'audio'),
    if (kind == 'audio') ...{
      'sampleRate': int.tryParse('${stream['sample_rate']}'),
      'channels': stream['channels'],
    },
    if (kind == 'image') ...{
      'width': stream['width'],
      'height': stream['height'],
      'pixelFormat': stream['pix_fmt'],
      'hasAlpha': _imageHasAlpha(stream),
      'rotationDegrees': _imageRotation(stream),
    },
  };
}

bool _imageHasAlpha(Map<String, Object?> stream) {
  final pixels = stream['pix_fmt']?.toString() ?? '';
  return pixels.startsWith('yuva') ||
      pixels.startsWith('gbrap') ||
      pixels.contains('rgba') ||
      pixels.contains('bgra') ||
      pixels.contains('argb') ||
      pixels.contains('abgr') ||
      pixels.startsWith('ya');
}

int _imageRotation(Map<String, Object?> stream) {
  final sideData = stream['side_data_list'];
  if (sideData is List<Object?>) {
    for (final item in sideData.whereType<Map<String, Object?>>()) {
      final rotation = double.tryParse('${item['rotation']}');
      if (rotation != null) return ((rotation.round() % 360) + 360) % 360;
    }
  }
  final tags = stream['tags'];
  final rotation = tags is Map<String, Object?> ? double.tryParse('${tags['rotate']}') : null;
  return (((rotation?.round() ?? 0) % 360) + 360) % 360;
}
