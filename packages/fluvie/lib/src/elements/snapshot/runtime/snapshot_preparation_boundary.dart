import 'package:flutter/widgets.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/rendering/runtime/preparation_scope.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';

/// Captures the actual mounted subtree, preserving its state and inherited data.
final class SnapshotPreparationBoundary extends StatefulWidget {
  /// Mounts one real Snapshot child under a stable capture boundary.
  const SnapshotPreparationBoundary({required this.snapshot, required this.child, super.key});

  /// The Snapshot declaration that determines its output capture key.
  final Widget snapshot;

  /// The authored subtree, built through normal Flutter semantics.
  final Widget child;
  @override
  State<SnapshotPreparationBoundary> createState() => SnapshotPreparationBoundaryState();
}

/// The preparation session reads this boundary without rebuilding its widget.
final class SnapshotPreparationBoundaryState extends State<SnapshotPreparationBoundary> {
  /// Identifies this mounted target while preserving its child across wrappers.
  final GlobalKey boundaryKey = GlobalKey(debugLabel: 'fluvie mounted snapshot');

  @override
  Widget build(BuildContext context) {
    final target = PreparationScope.snapshotTargetOf(context);
    final selected = identical(target, boundaryKey);
    Widget child = KeyedSubtree(key: boundaryKey, child: widget.child);
    // A nested GlobalKey keeps user component state when the capture wrappers
    // enter. The repaint boundary has a separate stable key for pixel readback.
    if (selected) {
      final scope = TimeScopeProvider.maybeOf(context);
      child = FrameProvider(
        frame: scope?.startFrame ?? FrameProvider.of(context).frame,
        child: SnapshotPreparationContent(child: child),
      );
    }
    return Offstage(
      offstage:
          target != null &&
          !selected &&
          context.getInheritedWidgetOfExactType<SnapshotPreparationContent>() == null,
      child: RepaintBoundary(key: _captureKey, child: child),
    );
  }

  final GlobalKey _captureKey = GlobalKey(debugLabel: 'fluvie snapshot raster');

  /// The repaint boundary to read after a selected preparation paint.
  GlobalKey get captureKey => _captureKey;
}
