part of 'video_probe_service.dart';

extension _NativeProbing on FfprobeVideoProbeService {
  Future<VideoProbeResult> _probeNative(String filePath) async {
    final tools = FfmpegMediaTools(ffprobePath: _binaryPath);
    try {
      final report = await tools.probeReport(filePath, whenCancelled: whenCancelled);
      final timeline = await tools.probeTimeline(filePath, whenCancelled: whenCancelled);
      return await _parse(jsonEncode(report), filePath, timeline: timeline);
    } on MediaProcessException catch (error) {
      throw FluvieEncodeException(
        'ffprobe ("$_binaryPath") failed while probing "$filePath": ${error.message}',
        exitCode: error.exitCode ?? -1,
        stderrTail: error.stderr,
      );
    } finally {
      await tools.closeAsync();
    }
  }
}
