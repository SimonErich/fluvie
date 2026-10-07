import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie_mobile_encoder/src/fluvie_mobile_encoder_exception.dart';
import 'package:fluvie_mobile_encoder/src/mobile_audio_materializer.dart';

/// Decodes compressed audio with Android MediaCodec or iOS AVFoundation.
///
/// Native code writes mono float32 PCM to disk, avoiding a large method-channel
/// payload. One decoded result is shared by beat and frequency analysis. Call
/// [dispose] when the preparation owner finishes.
final class NativePcmDecoder implements PcmDecoder {
  /// Creates a decoder with a configurable sample bound (about six minutes at
  /// 44.1 kHz by default). Inject a decoder or raise [maxSamples] for longer
  /// reactive tracks. Normal music playback does not require PCM analysis.
  NativePcmDecoder({
    MethodChannel channel = const MethodChannel('dev.fluvie/mobile_encoder'),
    MobileAudioMaterializer? materializer,
    Directory? cacheDir,
    this.maxSamples = 16000000,
    // ignore: prefer_initializing_formals — public injection parameters keep stable names.
  }) : _channel = channel,
       // ignore: prefer_initializing_formals — public injection parameters keep stable names.
       _materializer = materializer,
       _directory = cacheDir {
    if (maxSamples <= 0) throw ArgumentError.value(maxSamples, 'maxSamples', 'must be positive');
  }

  /// Maximum mono sample count accepted before allocating the DSP buffer.
  final int maxSamples;
  final MethodChannel _channel;
  final MobileAudioMaterializer? _materializer;
  Directory? _directory;
  bool _ownsDirectory = false;
  Future<Directory>? _directoryFuture;
  bool _disposed = false;
  final Map<String, Future<PcmAudio>> _cache = {};
  final Set<File> _files = {};

  @override
  Future<PcmAudio> decode(AudioSource source) {
    if (_disposed) throw StateError('NativePcmDecoder is disposed.');
    return _cache.putIfAbsent(source.cacheKey, () => _decode(source));
  }

  Future<PcmAudio> _decode(AudioSource source) async {
    final dir = await (_directoryFuture ??= _openDirectory());
    if (_disposed) throw StateError('NativePcmDecoder is disposed.');
    await dir.create(recursive: true);
    final output = File('${dir.path}/pcm_${source.cacheKey}.f32');
    _files.add(output);
    try {
      final materializer = _materializer ?? BundleAudioMaterializer(cacheDir: dir);
      final String path;
      if (source is FileAudioSource) {
        path = source.path;
      } else if (source is MemoryAudioSource) {
        final encoded = File('${dir.path}/encoded_${source.cacheKey}');
        _files.add(encoded);
        await encoded.writeAsBytes(source.bytes);
        path = encoded.path;
      } else {
        final input = switch (source) {
          AssetAudioSource() => source.name,
          NetworkAudioSource() => source.url.toString(),
          _ => throw StateError('Unsupported audio source'),
        };
        path = await materializer.materialize(input);
        if (_materializer == null && path != input) _files.add(File(path));
      }
      final facts = await _channel.invokeMapMethod<String, Object?>('decodePcm', {
        'path': path,
        'outputPath': output.path,
        'maxSamples': maxSamples,
      });
      final rate = facts?['sampleRate'];
      final count = facts?['sampleCount'];
      if (rate is! int || rate <= 0 || count is! int || count < 0 || count > maxSamples) {
        throw const FormatException('Invalid native PCM sample rate or count.');
      }
      if (await output.length() != count * 4) {
        throw const FormatException('Native PCM byte length does not match its sample count.');
      }
      final bytes = await output.readAsBytes();
      final view = ByteData.sublistView(bytes);
      final samples = Float64List(count);
      for (var index = 0; index < count; index++) {
        final value = view.getFloat32(index * 4, Endian.little);
        if (!value.isFinite || value < -1 || value > 1) {
          throw const FormatException('Native PCM contains an invalid normalized sample.');
        }
        samples[index] = value;
      }
      return (samples: samples, sampleRate: rate);
    } on Object catch (error) {
      unawaited(_cache.remove(source.cacheKey));
      throw FluvieMobileEncoderException(
        'Native audio analysis failed: $error',
        code: error is PlatformException ? error.code : 'pcm_decode_failed',
      );
    } finally {
      if (output.existsSync()) {
        await output.delete();
      }
      _files.remove(output);
    }
  }

  Future<Directory> _openDirectory() async {
    if (_directory == null) {
      _directory = await Directory.systemTemp.createTemp('fluvie_pcm_');
      _ownsDirectory = true;
    }
    return _directory!;
  }

  /// Releases decoded samples and temporary files owned by this decoder.
  /// Pass-through source files and files returned by an injected materializer
  /// remain caller-owned. A supplied cache directory is not removed.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _cache.clear();
    for (final file in _files) {
      if (file.existsSync()) await file.delete();
    }
    _files.clear();
    if (_directoryFuture != null) await _directoryFuture;
    if (_ownsDirectory && _directory!.existsSync()) await _directory!.delete(recursive: true);
  }
}
