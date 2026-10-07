import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart' show VideoSpec;
import 'package:fluvie/rendering.dart' show DesktopVideoRenderer, RenderCancellation, RenderPhase;
import 'package:slides/editor/deck_render_service.dart';
import 'package:slides/editor/desktop_render_surface.dart';

// coverage:ignore-start the desktop render drives a real save dialog a live
// engine surface and a local ffmpeg so tests fake the seam instead

/// The desktop renderer: the real fluvie pipeline against a local FFmpeg.
DeckRenderService platformDeckRenderService() => DesktopDeckRenderService();

/// Runs the desktop renderer, injecting only the destination picker for hosts.
final class DesktopDeckRenderService implements DeckRenderService {
  /// Uses the native save dialog unless [pickOutput] supplies a destination.
  DesktopDeckRenderService({Future<String?> Function(String suggestedName)? pickOutput})
    : _pickOutput = pickOutput ?? _saveDialog;

  final Future<String?> Function(String suggestedName) _pickOutput;

  static Future<String?> _saveDialog(String suggestedName) => FilePicker.saveFile(
    dialogTitle: 'Export video',
    fileName: suggestedName,
    type: FileType.custom,
    allowedExtensions: const ['mp4'],
  );

  @override
  bool get isAvailable => true;

  @override
  String get unavailableNote => 'always available on the desktop';

  @override
  Future<String?> renderToVideo({
    required VideoSpec spec,
    required String suggestedName,
    ExportOptions? options,
    RenderCancellation? cancellation,
    void Function(String phase)? onProgress,
  }) async {
    cancellation?.throwIfCancelled();
    final run = options ?? ExportOptions.forSpec(spec);
    final path = await _pickOutput(suggestedName);
    if (path == null) return null;
    cancellation?.throwIfCancelled();
    // The aspect family stays the deck's; only the long edge scales, because
    // sizeFor forces the family ratio either way.
    final aspect = aspectForSize(spec.size.width, spec.size.height);
    final longEdge = run.longEdge;
    final target = aspect.sizeFor(longEdge);
    final surface = DesktopRenderSurface(
      Size(target.width.toDouble(), target.height.toDouble()),
    );
    final renderer = DesktopVideoRenderer(
      pumpWidget: surface.mount,
      pumpFrame: surface.pumpFrame,
      cancellation: cancellation,
    );
    try {
      final video = run.applyTo(spec).build();
      final rendered = await renderer.render(
        composition: video,
        aspect: aspect,
        duration: renderDurationFor(video.totalFrames, spec.fps),
        fps: spec.fps,
        longEdge: longEdge,
        quality: run.quality,
        onProgress: (progress) => onProgress?.call(switch (progress.phase) {
          RenderPhase.capturing => 'Capturing frames',
          RenderPhase.encoding => 'Encoding',
          RenderPhase.complete => 'Finishing',
        }),
      );
      try {
        cancellation?.throwIfCancelled();
        await rendered.copy(path);
        return path;
      } finally {
        if (rendered.parent.existsSync()) await rendered.parent.delete(recursive: true);
      }
    } finally {
      await surface.dispose();
    }
  }
}

// coverage:ignore-end
