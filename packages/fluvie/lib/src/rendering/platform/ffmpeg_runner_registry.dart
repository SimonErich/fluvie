import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:fluvie/src/rendering/encoding/ffmpeg_runner.dart';
import 'package:fluvie/src/rendering/platform/process_ffmpeg_runner.dart';
import 'package:fluvie/src/rendering/platform/process_runner.dart';
import 'package:fluvie/src/rendering/platform/wasm_ffmpeg_runner.dart';
import 'package:fluvie/src/rendering/platform/wasm_runtime.dart';
import 'package:fluvie/src/rendering/platform/wasm_runtime_bindings.dart';
import 'package:riverpod/riverpod.dart';

/// Chooses the [FfmpegRunner] for a platform: the native process provider
/// everywhere except the web, where ffmpeg.wasm takes over.
final class FfmpegRunnerRegistry {
  // coverage:ignore-line const private ctor for the static facade registry
  const FfmpegRunnerRegistry._();

  /// Builds the provider for [isWeb], with every dependency injectable.
  ///
  /// Native: a [ProcessFfmpegRunner] over [runner] (default
  /// [IoProcessRunner]). Web: a [WasmFfmpegRunner] over [wasmFactory]
  /// (default: the real browser binding) — [readInput]/[writeOutput] must be
  /// wired by the web render path before an encode actually runs; the
  /// defaults fail loudly so a missing wire is a clear bug, not a hang.
  static FfmpegRunner select({
    required bool isWeb,
    ProcessRunner? runner,
    WasmRuntime Function()? wasmFactory,
    WasmInputReader? readInput,
    WasmOutputWriter? writeOutput,
  }) {
    if (!isWeb) {
      return ProcessFfmpegRunner(runner: runner ?? const IoProcessRunner());
    }
    return WasmFfmpegRunner(
      runtime: (wasmFactory ?? createWasmRuntime)(),
      readInput: readInput ?? _unwiredReadInput,
      writeOutput: writeOutput ?? _unwiredWriteOutput,
    );
  }

  // coverage:ignore-start web only fail loud defaults the VM render path never takes the isWeb branch so these unwired guards cannot run in a unit test
  static Future<Uint8List> _unwiredReadInput(String name) => throw UnsupportedError(
    'WasmFfmpegRunner has no readInput wired: the web render path must '
    'provide one to FfmpegRunnerRegistry.select before encoding "$name".',
  );

  static void _unwiredWriteOutput(String name, Uint8List bytes) => throw UnsupportedError(
    'WasmFfmpegRunner has no writeOutput wired: the web render path must '
    'provide one to FfmpegRunnerRegistry.select before encoding "$name".',
  );
  // coverage:ignore-end
}

/// The encode provider for the current platform ([kIsWeb] dispatch),
/// running processes through [processRunnerProvider]; overridable in tests.
final ffmpegRunnerProvider = Provider<FfmpegRunner>(
  (ref) => FfmpegRunnerRegistry.select(isWeb: kIsWeb, runner: ref.watch(processRunnerProvider)),
);
