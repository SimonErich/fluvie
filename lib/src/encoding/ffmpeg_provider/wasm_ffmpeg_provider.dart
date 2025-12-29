import 'ffmpeg_provider.dart';

// Conditional import for web support
// ignore: uri_does_not_exist
import 'wasm_ffmpeg_provider_stub.dart'
    if (dart.library.js_interop) 'wasm_ffmpeg_provider_web.dart'
    as impl;

/// FFmpeg provider that uses WebAssembly for browser support.
///
/// This provider enables video encoding in web browsers using FFmpeg compiled
/// to WebAssembly via [ffmpeg.wasm](https://ffmpegwasm.netlify.app/).
///
/// ## Setup
///
/// 1. Add the ffmpeg.wasm script to your `web/index.html`:
///
/// ```html
/// <script src="https://unpkg.com/@ffmpeg/ffmpeg@0.12.6/dist/umd/ffmpeg.js"></script>
/// <script src="https://unpkg.com/@ffmpeg/util@0.12.1/dist/umd/util.js"></script>
/// ```
///
/// 2. Configure your server with the required headers for SharedArrayBuffer:
///
/// ```
/// Cross-Origin-Embedder-Policy: require-corp
/// Cross-Origin-Opener-Policy: same-origin
/// ```
///
/// ## Limitations
///
/// - Slower than native FFmpeg due to WebAssembly overhead
/// - Memory limited by browser constraints
/// - No access to local file system (uses Blob URLs for output)
/// - Some FFmpeg features may not be available
class WasmFFmpegProvider implements FFmpegProvider {
  WasmFFmpegProvider();

  @override
  String get name => 'WASM (Web)';

  @override
  Future<bool> isAvailable() => impl.isAvailable();

  @override
  Future<FFmpegSession> startSession(FFmpegSessionConfig config) =>
      impl.startSession(config);

  @override
  Future<void> dispose() => impl.dispose();
}

/// Stub implementation for non-web platforms.
///
/// This class provides the interface but throws an error if used
/// on non-web platforms.
abstract class WasmFFmpegSession implements FFmpegSession {
  // Abstract interface for platform-specific implementations
}
