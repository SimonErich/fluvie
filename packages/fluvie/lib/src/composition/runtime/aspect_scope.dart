import 'package:flutter/widgets.dart';
import 'package:fluvie/src/core/aspect.dart';

/// Carries the active [Aspect] down to `Adaptive` and any element that branches
/// on [AspectScope.of] — the multi-aspect counterpart to the render-mode and
/// noise scopes.
///
/// `render(video, aspect:)` mounts one of these over the composition so the
/// whole subtree lays out for that aspect, while timing and animations resolve
/// identically across aspects (only layout branches). Unlike the frame clocks,
/// [of] is non-throwing: with no scope it falls back to [Aspect.fallback], so a
/// live preview and a stray `Adaptive` still have a sane default and need no
/// wrapper.
///
/// The scope widget is mounted by the render shell; authors read the active
/// aspect at build time through the [of] accessor.
final class AspectScope extends InheritedWidget {
  /// Provides [aspect] to every descendant of [child].
  const AspectScope({required this.aspect, required super.child, super.key});

  /// The aspect every descendant reads through [of] / [maybeOf].
  final Aspect aspect;

  /// The nearest aspect above [context], or [Aspect.fallback] when there is no
  /// [AspectScope] (a plain preview branches as [Aspect.reels]).
  ///
  /// This never throws: aspect is optional, so an `Adaptive` or an element
  /// reading the aspect outside any render still has a sane default.
  static Aspect of(BuildContext context) => maybeOf(context) ?? Aspect.fallback;

  /// The nearest aspect above [context], or `null` when no scope is present.
  ///
  /// [of] wraps this to provide the [Aspect.fallback] default; callers that need
  /// to distinguish "no scope" from the default use this directly.
  static Aspect? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AspectScope>()?.aspect;

  @override
  bool updateShouldNotify(AspectScope oldWidget) => oldWidget.aspect != aspect;
}
