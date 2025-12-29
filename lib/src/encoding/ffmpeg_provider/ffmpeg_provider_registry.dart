import 'package:flutter/foundation.dart' show kIsWeb;

import 'ffmpeg_provider.dart';
import 'process_ffmpeg_provider.dart';
import 'wasm_ffmpeg_provider.dart';

/// Registry for managing FFmpeg providers.
///
/// The registry determines which FFmpeg provider to use based on the platform
/// and allows users to set custom providers for advanced use cases.
///
/// ## Default Providers
///
/// - **Web**: [WasmFFmpegProvider] using ffmpeg.wasm
/// - **Desktop (Linux, macOS, Windows)**: [ProcessFFmpegProvider] using native FFmpeg
/// - **Mobile (Android, iOS)**: No default provider - must set custom
///
/// ## Custom Provider Example
///
/// For mobile platforms, you can use FFmpegKit:
///
/// ```dart
/// void main() {
///   // Set a custom provider for mobile
///   FFmpegProviderRegistry.setProvider(FFmpegKitProvider());
///   runApp(MyApp());
/// }
/// ```
class FFmpegProviderRegistry {
  static FFmpegProvider? _customProvider;
  static FFmpegProvider? _cachedDefaultProvider;

  /// Sets a custom FFmpeg provider.
  ///
  /// Call this before using any Fluvie rendering features.
  /// Typically called in your app's `main()` function.
  static void setProvider(FFmpegProvider provider) {
    _customProvider = provider;
    _cachedDefaultProvider?.dispose();
    _cachedDefaultProvider = null;
  }

  /// Clears any custom provider and resets to platform default.
  static void clearProvider() {
    _customProvider?.dispose();
    _customProvider = null;
  }

  /// Gets the current FFmpeg provider instance.
  ///
  /// Returns the custom provider if set, otherwise returns the appropriate
  /// default provider for the current platform.
  ///
  /// Throws [UnsupportedError] if no provider is available for the platform.
  static FFmpegProvider get instance {
    if (_customProvider != null) {
      return _customProvider!;
    }

    _cachedDefaultProvider ??= _createDefaultProvider();
    return _cachedDefaultProvider!;
  }

  /// Checks if an FFmpeg provider is available on the current platform.
  ///
  /// Returns `true` if a provider exists and FFmpeg is available.
  static Future<bool> isAvailable() async {
    try {
      return await instance.isAvailable();
    } catch (_) {
      return false;
    }
  }

  /// Gets the name of the current provider.
  static String get providerName {
    try {
      return instance.name;
    } catch (_) {
      return 'None';
    }
  }

  static FFmpegProvider _createDefaultProvider() {
    if (kIsWeb) {
      return WasmFFmpegProvider();
    }

    // For native platforms, use ProcessFFmpegProvider
    // This works on Linux, macOS, and Windows
    return ProcessFFmpegProvider();
  }

  /// Disposes all cached providers and cleans up resources.
  ///
  /// Call this when your app is shutting down or when you want to
  /// release FFmpeg resources.
  static Future<void> dispose() async {
    await _customProvider?.dispose();
    await _cachedDefaultProvider?.dispose();
    _customProvider = null;
    _cachedDefaultProvider = null;
  }
}
