import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_runner.dart';
import 'package:fluvie/src/rendering/platform/ffmpeg_runner_registry.dart';
import 'package:fluvie/src/rendering/platform/process_ffmpeg_runner.dart';
import 'package:fluvie/src/rendering/platform/wasm_ffmpeg_runner.dart';
import 'package:fluvie/src/rendering/platform/wasm_runtime.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class _MockWasmRuntime extends Mock implements WasmRuntime {}

class _MockFfmpegRunner extends Mock implements FfmpegRunner {}

void main() {
  group('FfmpegRunnerRegistry.select', () {
    test('native (isWeb: false) selects ProcessFfmpegRunner', () {
      final provider = FfmpegRunnerRegistry.select(isWeb: false);
      expect(provider, isA<ProcessFfmpegRunner>());
    });

    test('web (isWeb: true) selects WasmFfmpegRunner', () {
      final provider = FfmpegRunnerRegistry.select(
        isWeb: true,
        wasmFactory: _MockWasmRuntime.new,
      );
      expect(provider, isA<WasmFfmpegRunner>());
    });

    test('on the VM the default web wasmFactory is the throwing stub', () {
      expect(() => FfmpegRunnerRegistry.select(isWeb: true), throwsUnsupportedError);
    });
  });

  group('ffmpegRunnerProvider', () {
    test('resolves to the native provider on the VM (kIsWeb dispatch)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(ffmpegRunnerProvider), isA<ProcessFfmpegRunner>());
    });

    test('is overridable with a mock in a ProviderContainer', () {
      final mock = _MockFfmpegRunner();
      final container = ProviderContainer(
        overrides: [ffmpegRunnerProvider.overrideWithValue(mock)],
      );
      addTearDown(container.dispose);
      expect(container.read(ffmpegRunnerProvider), same(mock));
    });
  });
}
