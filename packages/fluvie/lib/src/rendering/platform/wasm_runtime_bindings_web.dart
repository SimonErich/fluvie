// coverage:ignore-file thin JS bridge exercised only by the manual
// wasm-tagged browser harness; CI covers the provider against a mock.
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:fluvie/src/rendering/platform/wasm_runtime.dart';

/// Web factory: binds [WasmRuntime] to the page-global `FluvieFfmpeg` object
/// (an ffmpeg.wasm wrapper exposing `load`/`writeFile`/`exec`/`readFile`)
/// that the browser harness page installs before tests run.
WasmRuntime createWasmRuntime() => _WebWasmRuntime();

final class _WebWasmRuntime implements WasmRuntime {
  JSObject get _bridge => globalContext.getProperty<JSObject>('FluvieFfmpeg'.toJS);
  Future<JSAny?> _call(String method, List<JSAny?> args) async =>
      _bridge.callMethodVarArgs<JSPromise<JSAny?>>(method.toJS, args).toDart;
  @override
  Future<void> load() => _call('load', const []);
  @override
  Future<void> writeFile(String name, Uint8List bytes) =>
      _call('writeFile', [name.toJS, bytes.toJS]);
  @override
  Future<int> exec(List<String> args) async =>
      ((await _call('exec', [
                [for (final a in args) a.toJS].toJS,
              ]))!
              as JSNumber)
          .toDartInt;
  @override
  Future<Uint8List> readFile(String name) async =>
      ((await _call('readFile', [name.toJS]))! as JSUint8Array).toDart;
}
