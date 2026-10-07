import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie_mobile_encoder/fluvie_mobile_encoder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('native_pcm_test');
  test('native PCM is bounded, normalized, file-backed and shared by both analyses', () async {
    final dir = Directory.systemTemp.createTempSync('fluvie_pcm_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        expect(call.method, 'decodePcm');
        final args = (call.arguments as Map).cast<String, Object?>();
        expect(args['path'], '/songs/cat.mp3');
        expect(args['maxSamples'], 4096);
        final data = ByteData(4096 * 4);
        for (var i = 0; i < 4096; i++) {
          data.setFloat32(i * 4, i.isEven ? 0.5 : -0.5, Endian.little);
        }
        await File(args['outputPath']! as String).writeAsBytes(data.buffer.asUint8List());
        calls++;
        return {'sampleRate': 44100, 'sampleCount': 4096};
      },
    );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final decoder = NativePcmDecoder(channel: channel, cacheDir: dir, maxSamples: 4096);
    const source = AudioSource.file('/songs/cat.mp3');
    final pcm = await decoder.decode(source);
    expect(pcm.sampleRate, 44100);
    expect(pcm.samples.take(2), [0.5, -0.5]);
    await SpectralBeatDetectionService(decoder: decoder).detect(source, fps: 30, totalFrames: 10);
    await SpectralFrequencyAnalyzer(decoder: decoder).analyze(source, fps: 30, totalFrames: 10);
    expect(calls, 1);
    await decoder.dispose();
    expect(dir.listSync(), isEmpty);
  });
  test('invalid native facts reject corrupt or unbounded PCM', () async {
    final dir = Directory.systemTemp.createTempSync('fluvie_pcm_bad');
    addTearDown(() => dir.deleteSync(recursive: true));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => {'sampleRate': 0, 'sampleCount': 1000000000},
    );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final decoder = NativePcmDecoder(channel: channel, cacheDir: dir, maxSamples: 10);
    await expectLater(
      decoder.decode(const AudioSource.file('/a.mp3')),
      throwsA(isA<FluvieMobileEncoderException>()),
    );
    await decoder.dispose();
  });

  test('disposing PCM analysis never deletes a pass-through source file', () async {
    final dir = await Directory.systemTemp.createTemp('fluvie_pcm_source_');
    addTearDown(() => dir.delete(recursive: true));
    final sourceFile = File('${dir.path}/original.mp3');
    await sourceFile.writeAsBytes([1, 2, 3]);
    final cache = Directory('${dir.path}/cache');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        final args = (call.arguments as Map).cast<String, Object?>();
        expect(args['path'], sourceFile.path);
        final data = ByteData(4)..setFloat32(0, 0.5, Endian.little);
        await File(args['outputPath']! as String).writeAsBytes(data.buffer.asUint8List());
        return {'sampleRate': 44100, 'sampleCount': 1};
      },
    );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final decoder = NativePcmDecoder(channel: channel, cacheDir: cache);
    addTearDown(decoder.dispose);

    final pcm = await decoder.decode(AudioSource.asset(sourceFile.path));
    expect(pcm.samples, [0.5]);
    await decoder.dispose();
    expect(await sourceFile.readAsBytes(), [1, 2, 3]);
    expect(cache.listSync(), isEmpty);
  });

  test('memory audio is staged unchanged and released when analysis is disposed', () async {
    final dir = await Directory.systemTemp.createTemp('fluvie_pcm_memory_');
    addTearDown(() => dir.delete(recursive: true));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        final args = (call.arguments as Map).cast<String, Object?>();
        expect(await File(args['path']! as String).readAsBytes(), [9, 8, 7]);
        final data = ByteData(8)
          ..setFloat32(0, 1, Endian.little)
          ..setFloat32(4, -1, Endian.little);
        await File(args['outputPath']! as String).writeAsBytes(data.buffer.asUint8List());
        return {'sampleRate': 48000, 'sampleCount': 2};
      },
    );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final decoder = NativePcmDecoder(channel: channel, cacheDir: dir, maxSamples: 2);
    addTearDown(decoder.dispose);

    final pcm = await decoder.decode(AudioSource.memory(Uint8List.fromList([9, 8, 7])));
    expect(pcm.samples, [1, -1]);
    expect(pcm.sampleRate, 48000);
    await decoder.dispose();
    expect(dir.listSync(), isEmpty);
  });

  test('disposing analysis removes its owned directory and prevents subsequent decoding', () async {
    late Directory owned;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        final args = (call.arguments as Map).cast<String, Object?>();
        final output = File(args['outputPath']! as String);
        owned = output.parent;
        final data = ByteData(4)..setFloat32(0, 0.5, Endian.little);
        await output.writeAsBytes(data.buffer.asUint8List());
        return {'sampleRate': 44100, 'sampleCount': 1};
      },
    );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final decoder = NativePcmDecoder(channel: channel);
    addTearDown(decoder.dispose);
    const source = AudioSource.file('/fixture/track.mp3');

    expect((await decoder.decode(source)).samples, [0.5]);
    expect(owned.existsSync(), isTrue);
    await decoder.dispose();
    expect(owned.existsSync(), isFalse);
    await decoder.dispose();
    expect(() => decoder.decode(source), throwsStateError);
  });

  test('corrupt PCM is rejected and a later decode can retry the same source', () async {
    final dir = await Directory.systemTemp.createTemp('fluvie_pcm_retry_');
    addTearDown(() => dir.delete(recursive: true));
    var corrupt = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        final args = (call.arguments as Map).cast<String, Object?>();
        final data = ByteData(4)..setFloat32(0, corrupt ? double.nan : 0.25, Endian.little);
        await File(args['outputPath']! as String).writeAsBytes(data.buffer.asUint8List());
        return {'sampleRate': 44100, 'sampleCount': 1};
      },
    );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final decoder = NativePcmDecoder(channel: channel, cacheDir: dir);
    addTearDown(decoder.dispose);
    const source = AudioSource.file('/fixture/track.mp3');

    await expectLater(
      decoder.decode(source),
      throwsA(
        isA<FluvieMobileEncoderException>().having(
          (error) => error.code,
          'decode failure',
          'pcm_decode_failed',
        ),
      ),
    );
    expect(dir.listSync(), isEmpty);
    corrupt = false;
    expect((await decoder.decode(source)).samples, [0.25]);
    await decoder.dispose();
    expect(dir.listSync(), isEmpty);
  });

  test('truncated PCM bytes produce an actionable failure and leave no output', () async {
    final dir = await Directory.systemTemp.createTemp('fluvie_pcm_truncated_');
    addTearDown(() => dir.delete(recursive: true));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        final args = (call.arguments as Map).cast<String, Object?>();
        await File(args['outputPath']! as String).writeAsBytes([1, 2, 3]);
        return {'sampleRate': 44100, 'sampleCount': 1};
      },
    );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final decoder = NativePcmDecoder(channel: channel, cacheDir: dir);
    addTearDown(decoder.dispose);

    await expectLater(
      decoder.decode(const AudioSource.file('/fixture/track.mp3')),
      throwsA(
        isA<FluvieMobileEncoderException>()
            .having((error) => error.code, 'decode failure', 'pcm_decode_failed')
            .having((error) => error.message, 'diagnostic', contains('byte length')),
      ),
    );
    expect(dir.listSync(), isEmpty);
  });
}
