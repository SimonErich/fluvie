import 'package:flutter/widgets.dart';

/// Provides animation timing context to descendant widgets.
///
/// [AnimationContext] enables automatic timing coordination between
/// parent and child animations. When a parent has an entry animation,
/// child animations can automatically offset their start time to begin
/// after the parent's entry completes.
///
/// ## How It Works
///
/// 1. Parent widgets with entry/exit animations wrap their children
///    with [AnimationContext]
/// 2. Child widgets (like [AnimatedProp]) read the context and calculate
///    their effective start frame relative to the parent's timing
/// 3. Negative offsets allow children to overlap with the parent's entry
///
/// ## Example
///
/// ```dart
/// AnimatedPositioned.fill(
///   startFrame: 30,
///   entryAnimation: PositionedAnimation.slideFromBottom(duration: 20),
///   child: VColumn(
///     children: [
///       // Starts at 30 + 20 + 5 = 55
///       AnimatedProp.slideUpFade(
///         offsetTime: 5,
///         child: Text('First'),
///       ),
///       // Starts at 30 + 20 + (-5) = 45 (overlaps with parent entry)
///       AnimatedProp.fadeIn(
///         offsetTime: -5,
///         child: Text('Overlap'),
///       ),
///     ],
///   ),
/// )
/// ```
class AnimationContext extends InheritedWidget {
  /// The absolute frame where this context's animation starts.
  final int contextStartFrame;

  /// The duration of the parent's entry animation in frames.
  ///
  /// Child animations use this to calculate when the parent's entry completes.
  final int entryDuration;

  /// The duration of the parent's exit animation in frames.
  final int exitDuration;

  /// The absolute frame where the parent's exit animation begins.
  ///
  /// This is typically [contextEndFrame] - [exitDuration].
  final int? exitStartFrame;

  /// The absolute frame where this context's animation ends.
  final int? contextEndFrame;

  /// Accumulated offset from all ancestor [AnimationContext]s.
  ///
  /// This enables deeply nested animations to correctly calculate
  /// their timing relative to the root animation.
  final int inheritedOffset;

  /// Creates an animation context.
  const AnimationContext({
    super.key,
    required this.contextStartFrame,
    this.entryDuration = 0,
    this.exitDuration = 0,
    this.exitStartFrame,
    this.contextEndFrame,
    this.inheritedOffset = 0,
    required super.child,
  });

  /// The absolute frame where the parent's entry animation completes.
  ///
  /// This is [contextStartFrame] + [entryDuration].
  int get entryCompleteFrame => contextStartFrame + entryDuration;

  /// Calculates the effective start frame for a child animation.
  ///
  /// If [afterParentEntry] is true (default), the child starts after
  /// the parent's entry animation completes. The [offsetFrames] is then
  /// added to that point.
  ///
  /// Use negative [offsetFrames] to have the child start before the
  /// parent's entry completes (overlapping animation).
  ///
  /// Example:
  /// ```dart
  /// // Parent starts at frame 30, entry takes 20 frames
  /// // With offsetFrames: 5 and afterParentEntry: true
  /// // Result: 30 + 20 + 5 = 55
  ///
  /// // With offsetFrames: -5 and afterParentEntry: true
  /// // Result: 30 + 20 + (-5) = 45 (overlaps by 5 frames)
  /// ```
  int effectiveStartFrame({
    int offsetFrames = 0,
    bool afterParentEntry = true,
  }) {
    if (afterParentEntry) {
      return entryCompleteFrame + offsetFrames + inheritedOffset;
    }
    return contextStartFrame + offsetFrames + inheritedOffset;
  }

  /// Calculates the effective end frame for a child animation.
  ///
  /// If [beforeParentExit] is true (default), the child ends before
  /// the parent's exit animation begins. The [offsetFrames] is then
  /// subtracted from that point.
  int? effectiveEndFrame({int offsetFrames = 0, bool beforeParentExit = true}) {
    if (contextEndFrame == null) return null;

    if (beforeParentExit && exitStartFrame != null) {
      return exitStartFrame! - offsetFrames;
    }
    return contextEndFrame! - offsetFrames;
  }

  /// Whether the parent is currently in its entry phase.
  bool isInEntryPhase(int frame) {
    return frame >= contextStartFrame && frame < entryCompleteFrame;
  }

  /// Whether the parent is currently in its exit phase.
  bool isInExitPhase(int frame) {
    if (exitStartFrame == null || contextEndFrame == null) return false;
    return frame >= exitStartFrame! && frame < contextEndFrame!;
  }

  /// Gets the animation context from the widget tree.
  ///
  /// Returns null if no [AnimationContext] is found in the tree.
  static AnimationContext? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AnimationContext>();
  }

  /// Creates a nested context with accumulated offset.
  ///
  /// Use this when creating nested animated containers to properly
  /// accumulate timing offsets.
  AnimationContext nested({
    required int childStartFrame,
    int childEntryDuration = 0,
    int childExitDuration = 0,
    int? childEndFrame,
    int additionalOffset = 0,
    required Widget child,
  }) {
    return AnimationContext(
      contextStartFrame: childStartFrame,
      entryDuration: childEntryDuration,
      exitDuration: childExitDuration,
      contextEndFrame: childEndFrame,
      exitStartFrame: childEndFrame != null
          ? childEndFrame - childExitDuration
          : null,
      inheritedOffset: inheritedOffset + additionalOffset,
      child: child,
    );
  }

  @override
  bool updateShouldNotify(AnimationContext oldWidget) {
    return contextStartFrame != oldWidget.contextStartFrame ||
        entryDuration != oldWidget.entryDuration ||
        exitDuration != oldWidget.exitDuration ||
        exitStartFrame != oldWidget.exitStartFrame ||
        contextEndFrame != oldWidget.contextEndFrame ||
        inheritedOffset != oldWidget.inheritedOffset;
  }
}
