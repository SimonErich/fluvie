import 'dart:typed_data';

/// A loaded ffmpeg.wasm instance with its in-memory virtual file system.
///
/// This is the browser-side counterpart to `ProcessRunner`: the one seam
/// between `WasmFfmpegRunner` and JavaScript. CI exercises the full
/// provider logic on the VM against a mock of this contract; the real
/// JS-interop binding lives in the conditional `wasm_runtime_bindings` and
/// only runs in the manual, `wasm`-tagged browser harness.
abstract interface class WasmRuntime {
  /// Loads the wasm module (fetching and compiling it). Idempotency is the
  /// caller's job — the provider calls this exactly once per runtime.
  Future<void> load();

  /// Writes [bytes] into the runtime's virtual file system as [name].
  Future<void> writeFile(String name, Uint8List bytes);

  /// Runs one FFmpeg invocation with the argument array [args] and completes
  /// with its exit code (`0` means success).
  Future<int> exec(List<String> args);

  /// Reads the file [name] back out of the virtual file system.
  Future<Uint8List> readFile(String name);
}

/// Optional lifecycle supported by the browser bridge. Kept separate so custom
/// runtimes can state honestly whether they can terminate a running encode.
abstract interface class WasmRuntimeLifecycle {
  /// Stops the worker and releases its virtual filesystem. A later load starts fresh.
  Future<void> terminate();

  /// Removes one staged file from the worker filesystem after a completed job.
  Future<void> deleteFile(String name);
}
