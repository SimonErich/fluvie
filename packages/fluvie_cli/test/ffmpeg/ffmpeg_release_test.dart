import 'dart:ffi';

import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_release.dart';
import 'package:test/test.dart';

void main() {
  group('ffmpegAssetFor', () {
    test('linuxX64 is a BtbN GPL tar.xz with a nested bin/ffmpeg', () {
      final asset = ffmpegAssetFor(Abi.linuxX64);
      expect(asset.format, FfmpegArchiveFormat.tarXz);
      expect(asset.url, startsWith('https://github.com/BtbN/FFmpeg-Builds/'));
      expect(asset.url, endsWith('linux64-gpl-8.1.tar.xz'));
      expect(asset.archiveBinaryPath, endsWith('/bin/ffmpeg'));
      expect(
        asset.sha256,
        '0d14781b885c491f5c3b799cbe7d3a26ba8a7eb01935483185e31ea7d79c8cd3',
      );
      expect(asset.sizeBytes, 142879584);
    });

    test('linuxArm64 is the arm64 BtbN GPL tar.xz', () {
      final asset = ffmpegAssetFor(Abi.linuxArm64);
      expect(asset.format, FfmpegArchiveFormat.tarXz);
      expect(asset.url, endsWith('linuxarm64-gpl-8.1.tar.xz'));
      expect(
        asset.sha256,
        'e43b652753a7294d54e73e5d7d4040735cdad3c2f1439c4b2bbd6d275649ab31',
      );
    });

    test('windowsX64 is a zip whose inner binary is ffmpeg.exe', () {
      final asset = ffmpegAssetFor(Abi.windowsX64);
      expect(asset.format, FfmpegArchiveFormat.zip);
      expect(asset.url, endsWith('win64-gpl-8.1.zip'));
      expect(asset.archiveBinaryPath, endsWith('/bin/ffmpeg.exe'));
    });

    test('macosX64 is the evermeet zip with a bare ffmpeg entry', () {
      final asset = ffmpegAssetFor(Abi.macosX64);
      expect(asset.url, startsWith('https://evermeet.cx/'));
      expect(asset.format, FfmpegArchiveFormat.zip);
      expect(asset.archiveBinaryPath, 'ffmpeg');
    });

    test('macosArm64 is the osxexperts zip with a bare ffmpeg entry', () {
      final asset = ffmpegAssetFor(Abi.macosArm64);
      expect(asset.url, startsWith('https://www.osxexperts.net/'));
      expect(asset.format, FfmpegArchiveFormat.zip);
      expect(asset.archiveBinaryPath, 'ffmpeg');
    });

    test('every pinned URL is HTTPS and carries a 64-char SHA-256', () {
      for (final abi in const [
        Abi.linuxX64,
        Abi.linuxArm64,
        Abi.windowsX64,
        Abi.macosX64,
        Abi.macosArm64,
      ]) {
        final asset = ffmpegAssetFor(abi);
        expect(asset.url, startsWith('https://'));
        expect(asset.sha256, hasLength(64));
        expect(asset.sizeBytes, greaterThan(0));
      }
    });

    test('an unsupported platform throws a CliFailure that names the escape', () {
      expect(
        () => ffmpegAssetFor(Abi.linuxIA32),
        throwsA(
          isA<CliFailure>()
              .having((e) => e.message, 'message', contains('no pinned'))
              .having((e) => e.message, 'message', contains('FLUVIE_FFMPEG')),
        ),
      );
    });

    test('the pinned version label is exposed for the cache and status', () {
      expect(pinnedFfmpegVersion, isNotEmpty);
      expect(pinnedFfmpegBuildLabel, contains('GPL'));
    });

    test('defaults to the host ABI when no target is given', () {
      expect(ffmpegAssetFor(), isA<FfmpegAsset>());
    });
  });
}
