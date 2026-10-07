import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:slides/editor/audio_preview_platform_contract.dart';
import 'package:web/web.dart' as web;

AudioPreviewPlatform createAudioPreviewPlatform() => _WebAudioPreview();

final class _WebAudioPreview implements AudioPreviewPlatform {
  web.AudioContext? _context;
  web.AudioBufferSourceNode? _output;
  Completer<void>? _finished;
  int _epoch = 0;
  bool _disposed = false;
  web.AudioContext get _audio => _context ??= web.AudioContext();
  @override
  void unlock() {
    if (!_disposed) unawaited(_audio.resume().toDart);
  }

  @override
  Future<PcmAudio> decode(
    AudioSource source, {
    Uint8List? bytes,
    MediaResolver? resolver,
    NetworkAllowlist? allowlist,
  }) async {
    if (_disposed) throw StateError('Audio preview disposed');
    var content = bytes;
    if (content == null) {
      if (source is MemoryAudioSource) {
        content = source.bytes;
      } else if (source is AssetAudioSource) {
        final data = await rootBundle.load(source.name);
        content = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      } else if (source is NetworkAudioSource) {
        if (allowlist == null) {
          throw StateError('Network audio requires an allowed host: ${source.url.host}');
        }
        allowlist.check(source.url);
        final response = await web.window.fetch(source.url.toString().toJS).toDart;
        if (!response.ok) throw StateError('Audio request returned ${response.status}');
        content = (await response.arrayBuffer().toDart).toDart.asUint8List();
      } else {
        throw StateError('Import local audio into the browser before auditioning it.');
      }
    }
    final buffer = await _audio.decodeAudioData(Uint8List.fromList(content).buffer.toJS).toDart;
    if (buffer.length * 8 > 128 * 1024 * 1024) {
      throw StateError('Audio source exceeds the 128 MiB decoded preview budget');
    }
    final samples = Float64List(buffer.length);
    for (var channel = 0; channel < buffer.numberOfChannels; channel++) {
      final data = buffer.getChannelData(channel).toDart;
      for (var i = 0; i < samples.length; i++) {
        samples[i] += data[i] / buffer.numberOfChannels;
      }
    }
    return (samples: samples, sampleRate: buffer.sampleRate.round());
  }

  @override
  Future<void> play(Uint8List wav, {double offsetSeconds = 0}) async {
    final epoch = ++_epoch;
    await _halt();
    if (_disposed || epoch != _epoch) return;
    final context = _audio;
    await context.resume().toDart;
    if (context.state == 'suspended') {
      throw StateError('Audio output is paused by the browser. Press Play again.');
    }
    final buffer = await context.decodeAudioData(Uint8List.fromList(wav).buffer.toJS).toDart;
    if (_disposed || epoch != _epoch) return;
    final node = context.createBufferSource()
      ..buffer = buffer
      ..connect(context.destination);
    final done = Completer<void>();
    _output = node;
    _finished = done;
    node
      ..onended = ((web.Event event) {
        if (!done.isCompleted) done.complete();
      }).toJS
      ..start(0, offsetSeconds.clamp(0, buffer.duration));
    await done.future;
    node.disconnect();
    if (identical(_output, node)) {
      _output = null;
      _finished = null;
    }
  }

  @override
  Future<void> stop() async {
    _epoch++;
    await _halt();
  }

  Future<void> _halt() async {
    _output?.stop();
    _output = null;
    final done = _finished;
    _finished = null;
    if (done != null && !done.isCompleted) done.complete();
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await stop();
    await _context?.close().toDart;
    _context = null;
  }
}
