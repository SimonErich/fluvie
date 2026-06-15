import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_provider.dart';
import 'package:fluvie/src/rendering/platform/ffmpeg_provider_registry.dart';
import 'package:fluvie/src/rendering/platform/process_ffmpeg_provider.dart';
import 'package:fluvie/src/rendering/platform/wasm_ffmpeg_provider.dart';
import 'package:fluvie/src/rendering/platform/wasm_runtime.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class _MockWasmRuntime extends Mock implements WasmRuntime {}

class _MockFfmpegProvider extends Mock implements FfmpegProvider {}

void main() {
  group('FfmpegProviderRegistry.select', () {
    test('native (isWeb: false) selects ProcessFfmpegProvider', () {
      final provider = FfmpegProviderRegistry.select(isWeb: false);
      expect(provider, isA<ProcessFfmpegProvider>());
    });

    test('web (isWeb: true) selects WasmFfmpegProvider', () {
      final provider = FfmpegProviderRegistry.select(
        isWeb: true,
        wasmFactory: _MockWasmRuntime.new,
      );
      expect(provider, isA<WasmFfmpegProvider>());
    });

    test('on the VM the default web wasmFactory is the throwing stub', () {
      expect(() => FfmpegProviderRegistry.select(isWeb: true), throwsUnsupportedError);
    });
  });

  group('ffmpegProviderProvider', () {
    test('resolves to the native provider on the VM (kIsWeb dispatch)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(ffmpegProviderProvider), isA<ProcessFfmpegProvider>());
    });

    test('is overridable with a mock in a ProviderContainer', () {
      final mock = _MockFfmpegProvider();
      final container = ProviderContainer(
        overrides: [ffmpegProviderProvider.overrideWithValue(mock)],
      );
      addTearDown(container.dispose);
      expect(container.read(ffmpegProviderProvider), same(mock));
    });
  });
}
