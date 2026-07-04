import 'package:fluvie/src/rendering/platform/wasm_runtime.dart';

/// VM stub: there is no ffmpeg.wasm outside the browser.
///
/// Native platforms encode through `ProcessFfmpegRunner`; this factory is
/// only reachable when something on the VM asks for the web runtime, which
/// is a wiring bug worth failing loudly on.
WasmRuntime createWasmRuntime() => throw UnsupportedError(
  'ffmpeg.wasm is web-only: createWasmRuntime() has no VM implementation. '
  'Use ProcessFfmpegRunner on native platforms.',
);
