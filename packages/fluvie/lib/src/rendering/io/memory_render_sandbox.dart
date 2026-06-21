import 'dart:convert';
import 'dart:typed_data';

import 'package:fluvie/src/rendering/io/render_sandbox.dart';

/// An in-memory [RenderSandbox]: every file lives in a map of bytes.
///
/// Used on the web, where there is no file system — the captured frames, the
/// manifest, the materialized encoder inputs, and the encoded output are all
/// held as bytes and handed to ffmpeg.wasm's virtual file system. Pure Dart, so
/// it also runs in unit tests on the VM.
final class MemoryRenderSandbox implements RenderSandbox {
  /// Creates an empty in-memory sandbox.
  MemoryRenderSandbox();

  final Map<String, Uint8List> _files = {};

  /// The names currently held, in insertion order (for tests and inspection).
  Iterable<String> get names => _files.keys;

  @override
  String? get directoryPath => null;

  @override
  Future<void> create() async {}

  @override
  CaptureSink openFrames(String name) => _MemoryCaptureSink(_files, name);

  @override
  Future<void> writeText(String name, String content) async {
    _files[name] = Uint8List.fromList(utf8.encode(content));
  }

  @override
  Future<void> writeBytes(String name, Uint8List bytes) async {
    _files[name] = bytes;
  }

  @override
  Future<Uint8List> readBytes(String name) async {
    final bytes = _files[name];
    if (bytes == null) {
      throw StateError('No sandbox entry named "$name".');
    }
    return bytes;
  }
}

final class _MemoryCaptureSink implements CaptureSink {
  _MemoryCaptureSink(this._files, this._name);

  final Map<String, Uint8List> _files;
  final String _name;
  final BytesBuilder _buffer = BytesBuilder(copy: false);

  @override
  void add(Uint8List bytes) => _buffer.add(bytes);

  @override
  Future<void> close() async {
    _files[_name] = _buffer.takeBytes();
  }
}
