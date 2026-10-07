import 'dart:io';

import 'package:fluvie_media/src/toolchain_build.dart';

/// Resolves explicit/environment binaries, then the managed cache, then PATH.
String resolveMediaExecutable(String name, {String? explicit, Map<String, String>? environment}) {
  if (explicit != null && explicit.isNotEmpty) return explicit;
  final env = environment ?? Platform.environment;
  final override = env[name == 'ffprobe' ? 'FLUVIE_FFPROBE' : 'FLUVIE_FFMPEG'];
  if (override != null && override.isNotEmpty) return override;
  final base = Platform.isWindows
      ? env['LOCALAPPDATA']
      : env['XDG_CACHE_HOME'] ??
            (env['HOME'] == null ? null : '${env['HOME']}${Platform.pathSeparator}.cache');
  final abi = RegExp('on "([a-z0-9_]+)"').firstMatch(Platform.version)?.group(1);
  if (base != null && base.isNotEmpty && abi != null) {
    final path = [
      base,
      'fluvie',
      'toolchains',
      managedFfmpegBuildId,
      abi,
      'bin',
      if (Platform.isWindows) '$name.exe' else name,
    ].join(Platform.pathSeparator);
    if (File(path).existsSync()) return path;
  }
  return name;
}
