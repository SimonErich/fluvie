import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart' show LivePlayer, Video, VideoSpec, introspectTimeline;
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/transport/frame_range.dart';
import 'package:fluvie_editor/src/transport/slide_transport.dart';
import 'package:obers_ui/obers_ui.dart';

/// Plays the boundary into [slide] with the real render machinery: the
/// previous and current scenes build as a two-scene composition against the
/// document's own anchor table, so the `SharedElement` morph in the preview
/// is exactly the morph the file render and the presenter play. Playback
/// loops from one second before the blend window to the end of the slide.
final class MorphPreview extends StatefulWidget {
  /// Previews the boundary from slide `slide - 1` into [slide].
  const MorphPreview({required this.document, required this.slide, super.key});

  /// The deck being edited.
  final EditorDocument document;

  /// The slide being morphed into; must have a previous slide.
  final int slide;

  @override
  State<MorphPreview> createState() => _MorphPreviewState();
}

final class _MorphPreviewState extends State<MorphPreview> {
  late final Video _video;
  late final SlideTransport _transport;

  @override
  void initState() {
    super.initState();
    final spec = widget.document.spec;
    _video = VideoSpec(
      scenes: [spec.scenes[widget.slide - 1], spec.scenes[widget.slide]],
      size: spec.size,
      fps: spec.fps,
      motionDefaults: spec.motionDefaults,
      transition: spec.transition,
      theme: spec.theme,
      masters: spec.masters,
      anchors: spec.anchors,
    ).build();
    final introspection = introspectTimeline(_video);
    final incoming = introspection.scenes.last.span;
    final leadIn = math.max(0, incoming.start - spec.fps);
    _transport = SlideTransport(fps: spec.fps, length: incoming.end, initialFrame: leadIn)
      ..setLoop(FrameRange(leadIn, incoming.end))
      ..play();
  }

  @override
  void dispose() {
    _transport.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.document.spec.size;
    return LivePlayer(
      controller: _transport.controller,
      child: FittedBox(
        child: SizedBox(
          width: size.width.toDouble(),
          height: size.height.toDouble(),
          child: _video,
        ),
      ),
    );
  }
}

/// Opens the morph preview for [slide] of [document] in a dialog with an
/// explicit Close action.
Future<void> showMorphPreview(
  BuildContext context, {
  required EditorDocument document,
  required int slide,
}) {
  final size = document.spec.size;
  final height = 320 * size.height / math.max(1, size.width);
  return OiDialogShell.show<void>(
    context: context,
    semanticLabel: 'Morph preview',
    maxWidth: 384,
    builder: (close) => OiDialog.standard(
      label: 'Morph preview',
      title: 'Morph preview',
      content: SizedBox(
        width: 320,
        height: height,
        child: MorphPreview(document: document, slide: slide),
      ),
      // Escape and the scrim already dismiss through the shell overlay; the
      // explicit action is the visible affordance.
      actions: [OiButton.ghost(label: 'Close', onTap: () => close(null))],
    ),
  );
}
