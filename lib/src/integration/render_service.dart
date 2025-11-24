import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/render_config.dart';
import '../presentation/video_composition.dart';
import '../presentation/clip.dart';
import '../capture/frame_sequencer.dart';
import '../encoding/video_encoder_service.dart';

final renderServiceProvider = Provider((ref) => RenderService());

class RenderService {
  final VideoEncoderService _encoderService;

  RenderService({VideoEncoderService? encoderService})
      : _encoderService = encoderService ?? VideoEncoderService();

  RenderConfig createConfigFromContext(BuildContext context) {
    final composition = VideoComposition.of(context);
    if (composition == null) {
      throw Exception('No VideoComposition found in context');
    }
    
    final config = composition.toConfig();
    final clips = <ClipConfig>[];
    
    void visit(Element element) {
      if (element.widget is Clip) {
        final clip = element.widget as Clip;
        clips.add(clip.toClipConfig());
      }
      element.visitChildren(visit);
    }
    
    (context as Element).visitChildren(visit);
    
    return RenderConfig(
      timeline: config.timeline,
      clips: clips,
    );
  }

  Future<String> execute({
    required RenderConfig config,
    required GlobalKey repaintBoundaryKey,
    required Function(int frame) onFrameUpdate,
  }) async {
    final sequencer = FrameSequencer(repaintBoundaryKey);
    final tempDir = await getTemporaryDirectory();
    final frameDir = Directory('${tempDir.path}/frames');
    
    if (await frameDir.exists()) {
      await frameDir.delete(recursive: true);
    }
    await frameDir.create();

    // Capture Loop
    for (int frame = 0; frame < config.timeline.durationInFrames; frame++) {
      // 1. Update state
      onFrameUpdate(frame);
      
      // Wait for build/paint to ensure the frame is ready.
      await Future.delayed(const Duration(milliseconds: 16));
      
      // 3. Capture
      try {
        final image = await sequencer.captureFrame();
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        
        if (byteData != null) {
          // Offload file writing to compute to avoid blocking the UI thread.
          // We copy the buffer because ByteData might be backed by external memory.
          await compute(_writeFrame, _FrameData(path, buffer));
        }
        image.dispose();
      } catch (e) {
        print('Error capturing frame $frame: $e');
      }
    }

    // Encode
    return await _encoderService.encode(
      config: config,
      frameDirectory: frameDir.path,
      outputFileName: 'output.mp4',
    );
  }
}

class _FrameData {
  final String path;
  final Uint8List bytes;

  _FrameData(this.path, this.bytes);
}

Future<void> _writeFrame(_FrameData data) async {
  final file = File(data.path);
  await file.writeAsBytes(data.bytes, flush: true);
}
