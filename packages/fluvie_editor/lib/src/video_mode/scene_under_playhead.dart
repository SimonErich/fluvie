import 'package:flutter/widgets.dart';
import 'package:fluvie_editor/src/transport/slide_transport.dart';
import 'package:fluvie_editor/src/video_mode/video_timebase.dart';

/// Rebuilds [builder] with the scene index under the shared playhead — and
/// only when that index changes, so the editing chrome (interaction target,
/// inspector scope) follows boundary crossings without rebuilding per
/// frame.
///
/// The mapping is [VideoTimebase.sceneAt] over the transport's frame: the
/// same introspection resolution the preview plays, so the interactive
/// layer and the stage can never disagree about which scene is under the
/// playhead.
final class SceneUnderPlayhead extends StatefulWidget {
  /// Follows [transport] through [timebase], rebuilding [builder] per scene
  /// change.
  const SceneUnderPlayhead({
    required this.transport,
    required this.timebase,
    required this.builder,
    super.key,
  });

  /// The whole-video playhead.
  final SlideTransport transport;

  /// The frame-to-scene mapping (rebuilt by the owner per document change).
  final VideoTimebase timebase;

  /// Builds the subtree for the scene under the playhead.
  final Widget Function(BuildContext context, int scene) builder;

  @override
  State<SceneUnderPlayhead> createState() => _SceneUnderPlayheadState();
}

final class _SceneUnderPlayheadState extends State<SceneUnderPlayhead> {
  late int _scene = widget.timebase.sceneAt(widget.transport.frame);

  @override
  void initState() {
    super.initState();
    widget.transport.frames.addListener(_onFrame);
  }

  @override
  void didUpdateWidget(SceneUnderPlayhead oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transport != widget.transport) {
      oldWidget.transport.frames.removeListener(_onFrame);
      widget.transport.frames.addListener(_onFrame);
    }
    _scene = widget.timebase.sceneAt(widget.transport.frame);
  }

  @override
  void dispose() {
    widget.transport.frames.removeListener(_onFrame);
    super.dispose();
  }

  void _onFrame() {
    final next = widget.timebase.sceneAt(widget.transport.frame);
    if (next != _scene) setState(() => _scene = next);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _scene);
}
