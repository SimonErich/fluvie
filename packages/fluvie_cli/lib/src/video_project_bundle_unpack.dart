part of 'video_project_bundle.dart';

Future<Map<String, Object?>> _unpackBundle(
  String zip,
  String destination, {
  required int maxBytes,
  required int maxFiles,
}) async {
  final target = Directory(p.absolute(destination));
  if (FileSystemEntity.typeSync(target.path) != FileSystemEntityType.notFound) {
    throw const CliFailure('Bundle destination already exists. Choose a new directory.');
  }
  await target.parent.create(recursive: true);
  final stage = await target.parent.createTemp('.fluvie-unpack-');
  InputFileStream? input;
  try {
    if (File(zip).lengthSync() > maxBytes + 8 * 1024 * 1024) {
      throw const CliFailure('Bundle exceeds its compressed-input budget.');
    }
    input = InputFileStream(zip);
    final directory = ZipDirectory()..read(input);
    final names = <String>{};
    var total = 0;
    if (directory.fileHeaders.length > maxFiles + 1) {
      throw const CliFailure('Too many bundle files.');
    }
    for (final header in directory.fileHeaders) {
      final name = header.filename;
      if (!_bundlePath(name) ||
          !names.add(name.toLowerCase()) ||
          ((header.externalFileAttributes >> 16) & 0xf000) == 0xa000) {
        throw const CliFailure('Unsafe, duplicate or symlink bundle entry.');
      }
      total += header.uncompressedSize;
      if (total > maxBytes) throw const CliFailure('Bundle exceeds its decompression budget.');
    }
    input.position = 0;
    final archive = ZipDecoder().decodeStream(input);
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final path = p.join(stage.path, file.name);
      File(path).parent.createSync(recursive: true);
      final output = _BoundedBundleOutput(path, file.size);
      try {
        file.writeContent(output);
      } finally {
        await output.close();
      }
      if (File(path).lengthSync() != file.size) {
        throw const CliFailure('Bundle entry size does not match.');
      }
    }
    final manifestFile = File(p.join(stage.path, 'bundle.json'));
    if (!manifestFile.existsSync() || manifestFile.lengthSync() > 8 * 1024 * 1024) {
      throw const CliFailure('Missing or oversized bundle manifest.');
    }
    final manifest = jsonDecode(await manifestFile.readAsString());
    if (manifest is! Map<String, Object?> ||
        manifest['schemaVersion'] != 1 ||
        manifest['files'] is! List ||
        manifest['entryFunction'] is! String ||
        !RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]*$').hasMatch(manifest['entryFunction']! as String) ||
        manifest['settings'] is! Map ||
        manifest['sourceRevision'] is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(manifest['sourceRevision']! as String)) {
      throw const CliFailure('Unsupported video bundle manifest.');
    }
    final expected = <String>{'bundle.json'};
    for (final record in (manifest['files']! as List).cast<Map<String, Object?>>()) {
      final path = record['path'];
      if (path is! String || !_bundlePath(path) || !expected.add(path)) {
        throw const CliFailure('Invalid bundle file record.');
      }
      final file = File(p.join(stage.path, path));
      if (!file.existsSync() ||
          file.lengthSync() != record['byteLength'] ||
          (await sha256.bind(file.openRead()).first).toString() != record['sha256']) {
        throw CliFailure('Bundle integrity check failed: $path');
      }
    }
    final actual = archive.files.where((file) => file.isFile).map((file) => file.name).toSet();
    if (expected.length != actual.length || !expected.containsAll(actual)) {
      throw const CliFailure('The bundle contains unrecorded files.');
    }
    final entry = manifest['entry'];
    if (entry is! String ||
        !entry.startsWith('project/') ||
        !entry.endsWith('.dart') ||
        !_bundlePath(entry) ||
        !expected.contains(entry) ||
        !expected.contains('project/pubspec.yaml') ||
        !expected.contains('project/pubspec.lock')) {
      throw const CliFailure('The bundle has no valid Dart project entry or pinned resolution.');
    }
    await stage.rename(target.path);
    return {...manifest, 'verified': true, 'directory': target.path};
  } finally {
    await input?.close();
    if (stage.existsSync()) await stage.delete(recursive: true);
  }
}

bool _bundlePath(String path) =>
    path.isNotEmpty &&
    !path.contains(r'\') &&
    !path.contains(':') &&
    !path.contains('\u0000') &&
    !p.posix.isAbsolute(path) &&
    !path.split('/').any((part) => part.isEmpty || part == '.' || part == '..');

final class _BoundedBundleOutput extends OutputStream {
  _BoundedBundleOutput(String path, this.limit)
    : _file = OutputFileStream(path),
      super(byteOrder: ByteOrder.littleEndian);
  final OutputFileStream _file;
  final int limit;
  int _written = 0;
  void _take(int count) {
    _written += count;
    if (_written > limit) throw const CliFailure('Bundle decompression exceeds its declared size.');
  }

  @override
  int get length => _file.length;
  @override
  void clear() => _file.clear();
  @override
  void flush() => _file.flush();
  @override
  Future<void> close() => _file.close();
  @override
  void closeSync() => _file.closeSync();
  @override
  void writeByte(int value) {
    _take(1);
    _file.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    _take(length ?? bytes.length);
    _file.writeBytes(bytes, length: length);
  }

  @override
  void writeStream(InputStream stream) {
    _take(stream.length);
    _file.writeStream(stream);
  }

  @override
  Uint8List subset(int start, [int? end]) => _file.subset(start, end);
}
