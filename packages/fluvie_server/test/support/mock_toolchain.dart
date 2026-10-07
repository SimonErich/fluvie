import 'dart:convert';

import 'package:fluvie_cli/fluvie_cli.dart';
import 'package:mocktail/mocktail.dart';

class _Process extends Mock implements ProcessRunner {}

class _Toolchain extends Mock {
  Future<FfmpegToolchain> call(
    ProcessRunner runner, {
    String? binary,
    String? probeBinary,
    String mode = 'managed',
    bool allowDownload = true,
    ProvisionLog? log,
  });
}

ToolchainResolver mockToolchain() {
  registerFallbackValue(_Process());
  registerFallbackValue((String message) {});
  final resolver = _Toolchain();
  when(
    () => resolver.call(
      any(),
      binary: any(named: 'binary'),
      probeBinary: any(named: 'probeBinary'),
      mode: any(named: 'mode'),
      allowDownload: any(named: 'allowDownload'),
      log: any(named: 'log'),
    ),
  ).thenAnswer(
    (_) async => const FfmpegToolchain(
      ffmpegPath: 'ffmpeg',
      ffprobePath: 'ffprobe',
      ffmpegVersion: '8.1',
      ffprobeVersion: '8.1',
      build: 'test',
    ),
  );
  return resolver.call;
}

void stubOutputProbe(ProcessRunner runner) {
  when(
    () => runner.run(
      'ffprobe',
      any(),
      workingDirectory: any(named: 'workingDirectory'),
    ),
  ).thenAnswer(
    (_) async => ProcessRunResult(
      exitCode: 0,
      stdout: jsonEncode({
        'streams': [
          {
            'codec_type': 'video',
            'width': 320,
            'height': 240,
            'avg_frame_rate': '30/1',
            'nb_frames': '48',
            'duration': '1.6',
            'codec_name': 'h264',
            'pix_fmt': 'yuv420p',
          },
        ],
        'format': {'duration': '1.6', 'format_name': 'mov,mp4'},
      }),
      stderr: '',
    ),
  );
}
