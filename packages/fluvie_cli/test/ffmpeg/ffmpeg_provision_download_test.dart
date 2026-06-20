@Tags(['download'])
@Timeout(Duration(minutes: 8))
library;

// Real provisioning proof: fetch the pinned FFmpeg build over the network,
// verify its checksum, install it into a throwaway cache, and confirm the
// extracted binary actually runs. Needs internet; excluded from `gate` via the
// `download` tag (run with `melos run test:download`).

import 'dart:io';

import 'package:fluvie_cli/src/ffmpeg/ffmpeg_cache.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_provisioner.dart';
import 'package:test/test.dart';

void main() {
  test('downloads, verifies and installs the pinned build into a temp cache', () async {
    final tmp = Directory.systemTemp.createTempSync('fluvie_ffmpeg_download_');
    addTearDown(() => tmp.deleteSync(recursive: true));

    final cache = FfmpegCache(environment: {'XDG_CACHE_HOME': tmp.path});
    final provisioner = FfmpegProvisioner(cache: cache);
    final logs = <String>[];

    final path = await provisioner.install(log: logs.add);

    expect(path, cache.binaryPath);
    expect(File(path).existsSync(), isTrue);
    expect(provisioner.isInstalled, isTrue);
    expect(logs, isNotEmpty);

    // The extracted binary runs on this machine and answers `-version`.
    final version = await Process.run(path, ['-version']);
    expect(version.exitCode, 0);
    expect(version.stdout.toString(), contains('ffmpeg version'));

    // A second install is a no-op (idempotent, no re-download).
    final again = await provisioner.install();
    expect(again, path);
  });
}
