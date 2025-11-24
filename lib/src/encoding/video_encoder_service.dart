import 'dart:io';
import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/return_code.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/render_config.dart';
import 'ffmpeg_filter_graph_builder.dart';

class VideoEncoderService {
  final FFmpegFilterGraphBuilder _filterGraphBuilder;

  VideoEncoderService({FFmpegFilterGraphBuilder? filterGraphBuilder})
      : _filterGraphBuilder = filterGraphBuilder ?? FFmpegFilterGraphBuilder();

  Future<String> encode({
    required RenderConfig config,
    required String frameDirectory,
    required String outputFileName,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final outputPath = '${tempDir.path}/$outputFileName';
    
    // Delete existing output
    final outputFile = File(outputPath);
    if (await outputFile.exists()) {
      await outputFile.delete();
    }

    final filterGraph = _filterGraphBuilder.build(config);
    
    // Construct command
    // -framerate ${config.timeline.fps}
    // -i $frameDirectory/frame_%d.png
    // -filter_complex "$filterGraph"
    // -map "[v_out]" (if we named it that)
    // -c:v libx264 -pix_fmt yuv420p
    // outputPath
    
    final command = [
      '-framerate', '${config.timeline.fps}',
      '-i', '$frameDirectory/frame_%d.png',
      '-filter_complex', filterGraph,
      '-map', '[v_out]',
      '-c:v', 'libx264',
      '-pix_fmt', 'yuv420p',
      outputPath
    ];

    print('Executing FFmpeg: ${command.join(' ')}');

    final session = await FFmpegKit.executeWithArguments(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      print('Encoding successful: $outputPath');
      return outputPath;
    } else {
      final logs = await session.getAllLogsAsString();
      throw Exception('FFmpeg encoding failed: $logs');
    }
  }
}
