part of 'ffmpeg_provisioner.dart';

extension on FfmpegProvisioner {
  Future<List<int>> _download(FfmpegAsset asset) async {
    final downloader = _downloader;
    final bytes = downloader is BoundedFfmpegDownloader
        ? await downloader.downloadBounded(asset.url, maxBytes: asset.sizeBytes)
        : await downloader.download(asset.url);
    if (bytes.length != asset.sizeBytes) {
      throw CliFailure(
        'The downloaded archive is ${bytes.length} bytes; expected ${asset.sizeBytes} bytes.',
      );
    }
    final digest = sha256.convert(bytes).toString();
    if (digest != asset.sha256) {
      throw CliFailure(
        'The downloaded archive failed its SHA-256 checksum (expected ${asset.sha256}, got $digest).',
      );
    }
    return bytes;
  }

  Future<void> _writeExecutable(String path, List<int> bytes) async {
    await File(path).writeAsBytes(bytes, flush: true);
    if (!Platform.isWindows) {
      final result = await _runner.run('chmod', ['+x', path]);
      if (result.exitCode != 0) throw const CliFailure('Could not mark the toolchain executable.');
    }
  }

  Future<bool> _usable(String path) async {
    try {
      return (await _runner.run(path, const ['-version'])).exitCode == 0;
    } on ProcessException {
      return false;
    }
  }

  Future<void> _probe(String path) async {
    if (!await _usable(path)) {
      throw CliFailure(
        'The provisioned binary at $path did not run. This build may be incompatible with the machine.',
      );
    }
  }
}
