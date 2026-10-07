import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:slides/editor/audio_preview_platform_contract.dart';

/// Process launcher used by the desktop audition adapter. Hosts can supply a
/// managed launcher; tests exercise its lifecycle without opening an audio device.
typedef AudioPreviewProcessStarter =
    Future<Process> Function(String executable, List<String> arguments);

AudioPreviewPlatform createAudioPreviewPlatform({AudioPreviewProcessStarter? startProcess}) =>
    _NativeAudioPreview(startProcess ?? _startProcess);

Future<Process> _startProcess(String executable, List<String> arguments) =>
    Process.start(executable, arguments);

final class _NativeAudioPreview implements AudioPreviewPlatform {
  _NativeAudioPreview(this._startProcess);

  final AudioPreviewProcessStarter _startProcess;
  Future<Directory>? _directory;
  Process? _output;
  final Set<Process> _decoders = {};
  int _epoch = 0;
  bool _disposed = false;
  Future<Directory> _temp() => _directory ??= Directory.systemTemp.createTemp('fluvie-audition-');
  @override
  void unlock() {}
  @override
  Future<PcmAudio> decode(
    AudioSource source, {
    Uint8List? bytes,
    MediaResolver? resolver,
    NetworkAllowlist? allowlist,
  }) async {
    if (_disposed) throw StateError('Audio preview is disposed');
    String path;
    File? staged;
    try {
      if (bytes != null || source is MemoryAudioSource) {
        final content = bytes ?? (source as MemoryAudioSource).bytes;
        staged = File('${(await _temp()).path}/${source.cacheKey}.source');
        await staged.writeAsBytes(content, flush: true);
        path = staged.path;
      } else if (source is FileAudioSource) {
        path = source.path;
      } else if (resolver != null) {
        await resolver.preResolveAudio([source]);
        path = resolver.materializedAudioPathFor(source);
      } else if (source is AssetAudioSource) {
        final content = await rootBundle.load(source.name);
        staged = File('${(await _temp()).path}/${source.cacheKey}.source');
        await staged.writeAsBytes(
          content.buffer.asUint8List(content.offsetInBytes, content.lengthInBytes),
        );
        path = staged.path;
      } else {
        final url = (source as NetworkAudioSource).url;
        if (allowlist == null) {
          throw StateError('Network audio requires an allowed host: ${url.host}');
        }
        allowlist.check(url);
        final client = HttpClient();
        try {
          final response = await (await client.getUrl(url)).close();
          if (response.statusCode != 200) {
            throw HttpException('Audio request returned ${response.statusCode}', uri: url);
          }
          staged = File('${(await _temp()).path}/${source.cacheKey}.source');
          await response.pipe(staged.openWrite());
          path = staged.path;
        } finally {
          client.close(force: true);
        }
      }
      if (_disposed) throw StateError('Audio preview disposed');
      final process = await _startProcess('ffmpeg', [
        '-v',
        'error',
        '-nostdin',
        '-i',
        path,
        '-vn',
        '-ac',
        '1',
        '-ar',
        '22050',
        '-f',
        'f32le',
        'pipe:1',
      ]);
      if (_disposed) {
        process.kill(ProcessSignal.sigkill);
        await Future.wait<void>([process.stdout.drain<void>(), process.stderr.drain<void>()]);
        await process.exitCode;
        throw StateError('Audio preview disposed');
      }
      _decoders.add(process);
      final data = BytesBuilder(copy: false);
      final errors = process.stderr.transform(utf8.decoder).join();
      try {
        await for (final chunk in process.stdout) {
          data.add(chunk);
          if (_disposed || data.length > 64 * 1024 * 1024) {
            process.kill(ProcessSignal.sigkill);
            await process.exitCode;
            await errors;
            throw StateError(
              _disposed
                  ? 'Audio preview disposed'
                  : 'Audio source exceeds the 128 MiB decoded preview budget',
            );
          }
        }
        final code = await process.exitCode;
        final error = await errors;
        if (code != 0) throw StateError('Audio decode failed: $error');
        final raw = data.takeBytes();
        final values = ByteData.sublistView(raw);
        final samples = Float64List(raw.length ~/ 4);
        for (var i = 0; i < samples.length; i++) {
          samples[i] = values.getFloat32(i * 4, Endian.little);
        }
        return (samples: samples, sampleRate: 22050);
      } finally {
        _decoders.remove(process);
      }
    } finally {
      if (staged != null && staged.existsSync()) await staged.delete();
    }
  }

  @override
  Future<void> play(Uint8List wav, {double offsetSeconds = 0}) async {
    final epoch = ++_epoch;
    await _halt();
    if (_disposed || epoch != _epoch) return;
    final file = File('${(await _temp()).path}/chunk-$epoch.wav');
    try {
      await file.writeAsBytes(wav);
      if (_disposed || epoch != _epoch) return;
      final process = await _startProcess('ffplay', [
        '-nodisp',
        '-autoexit',
        '-loglevel',
        'error',
        '-ss',
        '$offsetSeconds',
        file.path,
      ]);
      final error = process.stderr.transform(utf8.decoder).join();
      unawaited(process.stdout.drain<void>());
      if (_disposed || epoch != _epoch) {
        process.kill(ProcessSignal.sigkill);
        await process.exitCode;
        await error;
        return;
      }
      _output = process;
      final code = await process.exitCode;
      final message = await error;
      if (identical(_output, process)) _output = null;
      if (code != 0 && !_disposed && epoch == _epoch) {
        throw StateError('Audio output failed: $message');
      }
    } finally {
      if (file.existsSync()) await file.delete();
    }
  }

  @override
  Future<void> stop() async {
    _epoch++;
    await _halt();
  }

  Future<void> _halt() async {
    final output = _output;
    _output = null;
    if (output != null) {
      output.kill(ProcessSignal.sigkill);
      await output.exitCode;
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    for (final process in _decoders) {
      process.kill(ProcessSignal.sigkill);
    }
    await stop();
    final dir = await _directory;
    if (dir != null && dir.existsSync()) await dir.delete(recursive: true);
  }
}
