import '../encoding/ffmpeg_provider/ffmpeg_provider_registry.dart';

/// Diagnostics information about FFmpeg availability.
class FFmpegDiagnostics {
  /// Whether FFmpeg is available and working.
  final bool isAvailable;

  /// The name of the provider being used.
  final String providerName;

  /// The FFmpeg version string, if available.
  final String? version;

  /// Error message if FFmpeg is not available.
  final String? errorMessage;

  /// Installation instructions for the current platform.
  final String? installationInstructions;

  const FFmpegDiagnostics({
    required this.isAvailable,
    required this.providerName,
    this.version,
    this.errorMessage,
    this.installationInstructions,
  });

  @override
  String toString() {
    if (isAvailable) {
      return 'FFmpeg is available via $providerName${version != null ? ' ($version)' : ''}';
    }
    return 'FFmpeg is NOT available: ${errorMessage ?? 'Unknown error'}';
  }
}

/// Utility for checking FFmpeg availability and diagnosing issues.
///
/// Use this to verify FFmpeg is properly set up before attempting to render:
///
/// ```dart
/// final diagnostics = await FFmpegChecker.check();
/// if (!diagnostics.isAvailable) {
///   print('FFmpeg not found: ${diagnostics.errorMessage}');
///   print(diagnostics.installationInstructions);
/// }
/// ```
class FFmpegChecker {
  /// Checks if FFmpeg is available and returns diagnostic information.
  static Future<FFmpegDiagnostics> check() async {
    try {
      final provider = FFmpegProviderRegistry.instance;
      final available = await provider.isAvailable();

      if (available) {
        return FFmpegDiagnostics(
          isAvailable: true,
          providerName: provider.name,
          version: await _getVersion(),
        );
      } else {
        return FFmpegDiagnostics(
          isAvailable: false,
          providerName: provider.name,
          errorMessage: 'FFmpeg executable not found',
          installationInstructions: _getInstallInstructions(),
        );
      }
    } catch (e) {
      return FFmpegDiagnostics(
        isAvailable: false,
        providerName: 'None',
        errorMessage: e.toString(),
        installationInstructions: _getInstallInstructions(),
      );
    }
  }

  /// Quick check if FFmpeg is available.
  static Future<bool> isAvailable() async {
    return FFmpegProviderRegistry.isAvailable();
  }

  static Future<String?> _getVersion() async {
    // Version extraction would require running ffmpeg -version
    // For now, return null as the provider doesn't expose this
    return null;
  }

  static String _getInstallInstructions() {
    return '''
FFmpeg Installation Instructions:

Linux:
  Ubuntu/Debian: sudo apt install ffmpeg
  Fedora:        sudo dnf install ffmpeg
  Arch:          sudo pacman -S ffmpeg

macOS:
  brew install ffmpeg

Windows:
  1. Download from https://ffmpeg.org/download.html
  2. Extract to a folder (e.g., C:\\ffmpeg)
  3. Add the bin folder to your PATH environment variable

Web:
  FFmpeg.wasm is used automatically. Ensure your server sends:
    Cross-Origin-Opener-Policy: same-origin
    Cross-Origin-Embedder-Policy: require-corp

Custom Path:
  FluvieConfig.configure(ffmpegPath: '/path/to/ffmpeg');
''';
  }
}
