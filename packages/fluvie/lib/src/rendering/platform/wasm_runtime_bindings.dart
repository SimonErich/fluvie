/// Platform-conditional factory for the real `WasmRuntime`: a JS-interop
/// binding in the browser, a throwing stub everywhere else.
library;

export 'wasm_runtime_bindings_stub.dart'
    if (dart.library.js_interop) 'wasm_runtime_bindings_web.dart';
