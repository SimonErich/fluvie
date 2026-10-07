import 'dart:io';

import 'package:fluvie_media/native.dart';
import 'package:test/test.dart';

void main() {
  test(
    'tool paths honor explicit selection, environment, managed pair and PATH in order',
    () async {
      final cache = await Directory.systemTemp.createTemp('fluvie_path_cache_');
      addTearDown(() => cache.delete(recursive: true));
      final env = {'FLUVIE_FFMPEG': '/chosen/ffmpeg', 'FLUVIE_FFPROBE': '/chosen/ffprobe'};
      expect(
        resolveMediaExecutable('ffprobe', explicit: '/explicit/probe', environment: env),
        '/explicit/probe',
      );
      expect(resolveMediaExecutable('ffprobe', environment: env), '/chosen/ffprobe');
      expect(resolveMediaExecutable('ffmpeg', environment: env), '/chosen/ffmpeg');
      expect(resolveMediaExecutable('ffmpeg', environment: const {}), 'ffmpeg');
      for (final abi in ['linux_x64', 'linux_arm64', 'macos_x64', 'macos_arm64', 'windows_x64']) {
        final directory = Directory(
          '${cache.path}/fluvie/toolchains/$managedFfmpegBuildId/$abi/bin',
        )..createSync(recursive: true);
        File(
          '${directory.path}/${Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg'}',
        ).writeAsStringSync('fixture');
      }
      final cached = resolveMediaExecutable(
        'ffmpeg',
        environment: {
          'XDG_CACHE_HOME': cache.path,
          'LOCALAPPDATA': cache.path,
        },
      );
      expect(File(cached).existsSync(), isTrue);
      expect(cached, startsWith(cache.path));
      expect(
        resolveMediaExecutable('ffprobe', environment: {'HOME': '${cache.path}/absent'}),
        'ffprobe',
      );
    },
  );
}
