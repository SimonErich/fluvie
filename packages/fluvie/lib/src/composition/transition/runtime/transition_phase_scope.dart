import 'package:flutter/widgets.dart';

/// The active blend window seen by one scene shell: which [boundary] is
/// blending and its eased [progress] in `(0, 1]`.
@immutable
final class TransitionPhase {
  /// Creates a phase for the active [boundary] at [progress].
  const TransitionPhase({required this.boundary, required this.progress});

  /// The boundary index of the active blend (between scenes `boundary` and
  /// `boundary + 1`).
  final int boundary;

  /// The eased blend progress in `(0, 1]`.
  final double progress;

  @override
  bool operator ==(Object other) =>
      other is TransitionPhase && other.boundary == boundary && other.progress == progress;

  @override
  int get hashCode => Object.hash(TransitionPhase, boundary, progress);

  @override
  String toString() => 'TransitionPhase(boundary: $boundary, progress: $progress)';
}

/// Publishes the active [TransitionPhase] to a scene shell's subtree — the
/// always-mounted suppression signal a `SharedElementSlot` reads to know a
/// window is blending its boundary.
///
/// The compositor mounts one over every scene shell during a blend window
/// (and with `phase: null` outside one), so toggling it is a value change on
/// an inherited widget, never a tree-shape change: a suppressed slot stops
/// painting via a `markNeedsPaint` flag and its child keeps its Element.
final class TransitionPhaseScope extends InheritedWidget {
  /// Provides [phase] (or `null` outside a window) to every descendant of
  /// [child].
  const TransitionPhaseScope({required this.phase, required super.child, super.key});

  /// The active blend window, or `null` when nothing is blending this scene.
  final TransitionPhase? phase;

  /// The nearest phase above [context], or `null` when no scope is mounted.
  static TransitionPhase? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TransitionPhaseScope>()?.phase;

  @override
  bool updateShouldNotify(TransitionPhaseScope oldWidget) => oldWidget.phase != phase;
}
