import 'package:flutter/widgets.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';

/// Internal orthogonal preparation state; the preview/capture mode stays real.
final class PreparationScope extends InheritedWidget {
  /// Keeps the actual composition mounted while its resources are prepared.
  const PreparationScope({
    required this.preparing,
    required super.child,
    this.resolver,
    this.onAudioAnalysis,
    this.resolvingTiming = false,
    this.onTimingError,
    this.requireResource,
    this.snapshotTarget,
    super.key,
  });

  /// Whether Fluvie leaves should expose geometry without painting resources.
  final bool preparing;

  /// Metadata already available during the bounded discovery passes.
  final MediaResolver? resolver;

  /// Records an actual FrameContext audio read during resource discovery.
  final VoidCallback? onAudioAnalysis;

  /// Resources are warm and the mounted registrar can now resolve its plan.
  final bool resolvingTiming;

  /// A preparation host propagates timing failures before producing artifacts.
  final ValueChanged<FluvieTimingError>? onTimingError;

  /// Validates synchronous runtime lookups against the frozen preparation set.
  final void Function(Object source, String kind)? requireResource;

  /// The mounted Snapshot content selected for rasterization, if any.
  final GlobalKey? snapshotTarget;

  /// Preparation is separate from RenderMode so normal Flutter builders follow
  /// the same preview/capture branch they will follow in the final composition.
  static bool isPreparing(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PreparationScope>()?.preparing ?? false;

  /// Resource leaves paint normally only inside the selected snapshot content.
  static bool exposesOnlyGeometry(BuildContext context) =>
      isPreparing(context) &&
      context.dependOnInheritedWidgetOfExactType<SnapshotPreparationContent>() == null;

  /// Whether preparation is painting mounted boundaries before frame capture.
  static GlobalKey? snapshotTargetOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PreparationScope>()?.snapshotTarget;

  /// The current preparation metadata, when installed.
  static MediaResolver? resolverOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PreparationScope>()?.resolver;

  /// Requests audio analysis only when authored code reads an analysed band.
  static void requestAudioAnalysis(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PreparationScope>()?.onAudioAnalysis?.call();

  /// A frame-dependent leaf must have appeared or been declared before capture.
  static void requirePrepared(BuildContext context, Object source, String kind) {
    final scope = context.getInheritedWidgetOfExactType<PreparationScope>();
    if (scope != null && !scope.preparing) scope.requireResource?.call(source, kind);
  }

  /// Whether Video may freeze its registered timing plan in this phase.
  static bool shouldResolveTiming(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PreparationScope>();
    return scope == null || !scope.preparing || scope.resolvingTiming;
  }

  /// Returns true when a preparation host has accepted the timing failure.
  static bool reportTimingError(BuildContext context, FluvieTimingError error) {
    final handler = context.getInheritedWidgetOfExactType<PreparationScope>()?.onTimingError;
    if (handler == null) return false;
    handler(error);
    return true;
  }

  @override
  bool updateShouldNotify(PreparationScope oldWidget) =>
      preparing != oldWidget.preparing ||
      resolvingTiming != oldWidget.resolvingTiming ||
      !identical(snapshotTarget, oldWidget.snapshotTarget) ||
      !identical(resolver, oldWidget.resolver);
}

/// Marks the selected mounted Snapshot's child during its one rasterization.
final class SnapshotPreparationContent extends InheritedWidget {
  /// Lets only this selected mounted subtree paint resolved resources.
  const SnapshotPreparationContent({required super.child, super.key});
  @override
  bool updateShouldNotify(SnapshotPreparationContent oldWidget) => false;
}
