import 'dart:io';
import 'dart:typed_data';

import 'package:fluvie/src/rendering/io/render_sandbox.dart';

/// A file-backed [RenderSandbox] under a real [directory].
///
/// Writes through to disk exactly as the render pipeline always has (the same
/// `openWrite`/`writeAsString`/`writeAsBytes` calls), so desktop and mobile
/// renders stay byte-identical. A process-based encoder runs in [directory].
final class FileRenderSandbox implements RenderSandbox {
  /// Creates a sandbox over [directory].
  FileRenderSandbox(this.directory);

  /// The directory holding this render's files.
  final Directory directory;

  @override
  String? get directoryPath => directory.path;

  @override
  Future<void> create() async {
    await directory.create(recursive: true);
  }

  @override
  CaptureSink openFrames(String name) =>
      _IoCaptureSink(File('${directory.path}/$name').openWrite());

  @override
  Future<void> writeText(String name, String content) =>
      File('${directory.path}/$name').writeAsString(content, flush: true);

  @override
  Future<void> writeBytes(String name, Uint8List bytes) =>
      File('${directory.path}/$name').writeAsBytes(bytes, flush: true);

  @override
  Future<Uint8List> readBytes(String name) => File('${directory.path}/$name').readAsBytes();
}

final class _IoCaptureSink implements CaptureSink {
  _IoCaptureSink(this._sink);

  final IOSink _sink;

  @override
  void add(Uint8List bytes) => _sink.add(bytes);

  @override
  Future<void> close() => _sink.close();
}
