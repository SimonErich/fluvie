import 'dart:ffi' show Abi;

import 'package:fluvie_cli/src/cli_failure.dart';

/// How a downloaded FFmpeg asset is packaged.
enum FfmpegArchiveFormat {
  /// A `.tar.xz` archive (the BtbN Linux builds).
  tarXz,

  /// A `.zip` archive (the BtbN Windows builds and the macOS builds).
  zip,
}

/// One platform's pinned, frozen FFmpeg download.
///
/// Every field is a constant baked into Fluvie at release time: the URL points
/// at a build that never changes in place, and [sha256]/[sizeBytes] let the
/// provisioner reject any tampered or truncated download before it is trusted.
final class FfmpegAsset {
  /// Creates an asset description.
  const FfmpegAsset({
    required this.url,
    required this.format,
    required this.archiveBinaryPath,
    required this.sha256,
    required this.sizeBytes,
  });

  /// The frozen HTTPS URL of the archive to download.
  final String url;

  /// How [url]'s bytes are packaged.
  final FfmpegArchiveFormat format;

  /// The path of the `ffmpeg` executable inside the extracted archive (forward
  /// slashes, as stored in the archive entries — `bin/ffmpeg.exe` on Windows).
  final String archiveBinaryPath;

  /// The expected lowercase-hex SHA-256 of the downloaded archive bytes.
  final String sha256;

  /// The exact archive size in bytes (a cheap guard checked before hashing).
  final int sizeBytes;
}

/// The cache-subdirectory label of the pinned FFmpeg build Fluvie provisions.
const String pinnedFfmpegVersion = '8.1';

/// A human-facing description of the pinned build, shown by `fluvie ffmpeg
/// status` and the install log. Names the license flavor and the sources.
const String pinnedFfmpegBuildLabel = 'FFmpeg 8.1 GPL (BtbN 2026-05-31, evermeet, osxexperts)';

const String _btbnBase =
    'https://github.com/BtbN/FFmpeg-Builds/releases/download/autobuild-2026-05-31-13-22';

// Bumping the pin is a deliberate change: pick a retained build (BtbN keeps the
// last build of each month for two years), then for every asset URL run
// `curl -fsSL <url> | sha256sum` and `curl -fsSIL <url>` for the byte size, and
// update sha256/sizeBytes/url/archiveBinaryPath plus pinnedFfmpegVersion and the
// `_managedFfmpegVersion` mirror in the fluvie package. The `download`-tagged
// test then proves the new pin downloads, verifies and runs.

/// Returns the pinned FFmpeg asset for [target] (the host ABI by default).
///
/// Throws a [CliFailure] for a platform Fluvie ships no pinned build for, with
/// a hint to install FFmpeg manually and point `--ffmpeg` / `$FLUVIE_FFMPEG`
/// at it.
FfmpegAsset ffmpegAssetFor([Abi? target]) {
  final abi = target ?? Abi.current();
  return switch (abi) {
    Abi.linuxX64 => const FfmpegAsset(
      url: '$_btbnBase/ffmpeg-n8.1.1-9-g58d4114d36-linux64-gpl-8.1.tar.xz',
      format: FfmpegArchiveFormat.tarXz,
      archiveBinaryPath: 'ffmpeg-n8.1.1-9-g58d4114d36-linux64-gpl-8.1/bin/ffmpeg',
      sha256: '0d14781b885c491f5c3b799cbe7d3a26ba8a7eb01935483185e31ea7d79c8cd3',
      sizeBytes: 142879584,
    ),
    Abi.linuxArm64 => const FfmpegAsset(
      url: '$_btbnBase/ffmpeg-n8.1.1-9-g58d4114d36-linuxarm64-gpl-8.1.tar.xz',
      format: FfmpegArchiveFormat.tarXz,
      archiveBinaryPath: 'ffmpeg-n8.1.1-9-g58d4114d36-linuxarm64-gpl-8.1/bin/ffmpeg',
      sha256: 'e43b652753a7294d54e73e5d7d4040735cdad3c2f1439c4b2bbd6d275649ab31',
      sizeBytes: 123696464,
    ),
    Abi.windowsX64 => const FfmpegAsset(
      url: '$_btbnBase/ffmpeg-n8.1.1-9-g58d4114d36-win64-gpl-8.1.zip',
      format: FfmpegArchiveFormat.zip,
      archiveBinaryPath: 'ffmpeg-n8.1.1-9-g58d4114d36-win64-gpl-8.1/bin/ffmpeg.exe',
      sha256: '7fe1bb1e76edf97b8ec9e84fb32b96d125d846135b6b9218af772f5af2bd9065',
      sizeBytes: 220667969,
    ),
    Abi.macosX64 => const FfmpegAsset(
      url: 'https://evermeet.cx/ffmpeg/ffmpeg-8.1.2.zip',
      format: FfmpegArchiveFormat.zip,
      archiveBinaryPath: 'ffmpeg',
      sha256: 'e91df72a1ee7c26606f90dd2dd4dcccc6a75140ff9ea6fdd50faae828b82ba69',
      sizeBytes: 26037786,
    ),
    Abi.macosArm64 => const FfmpegAsset(
      url: 'https://www.osxexperts.net/ffmpeg81arm.zip',
      format: FfmpegArchiveFormat.zip,
      archiveBinaryPath: 'ffmpeg',
      sha256: 'ebb82529562b71170807bbc6b0e7eb4f0b13af8cbb0e085bb9e8f6fe709598ad',
      sizeBytes: 22547387,
    ),
    _ => throw CliFailure(
      'Fluvie has no pinned FFmpeg build for this platform ($abi). Install '
      'FFmpeg ${pinnedFfmpegVersion.split('.').first}.0 or newer yourself and '
      r'point --ffmpeg or $FLUVIE_FFMPEG at it.',
    ),
  };
}
