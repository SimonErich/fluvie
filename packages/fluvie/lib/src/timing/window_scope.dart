/// @docImport 'package:fluvie/src/timing/scene_scope.dart';
/// @docImport 'package:fluvie/src/timing/video_scope.dart';
library;

import 'package:flutter/widgets.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/timing/placement/window_resolver.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';

/// Mounts an element's alive-[window] as a nested scope inside the enclosing
/// [SceneScope] — the timing shell `.animate(window:)` wraps around an
/// element's subtree.
///
/// With a [window], relative times below resolve against it instead of the
/// scene; without one the element is alive for the whole scene and the
/// enclosing scope stays the nearest. A windowed scope
/// additionally carries its raw [TimeRange] for [maybeWindowOf], so nested
/// elements can inherit the window they live in when they register with a
/// composition.
final class WindowScope extends StatelessWidget {
  /// Creates a window scope spanning [window] above [child].
  const WindowScope({required this.child, this.window, super.key});

  /// The element's alive-window within its scene, or `null` for the whole
  /// scene (no nested scope is mounted).
  final TimeRange? window;

  /// The element's subtree.
  final Widget child;

  /// The nearest enclosing windowed scope's raw [TimeRange] above [context],
  /// or `null` when no enclosing element declares a window.
  ///
  /// A window-less [WindowScope] mounts no carrier, so lookups pass through
  /// it to the nearest windowed ancestor.
  static TimeRange? maybeWindowOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_WindowCarrier>()?.range;

  @override
  Widget build(BuildContext context) {
    final scene = TimeScopeProvider.maybeOf(context);
    if (scene == null) {
      throw FluvieTimingError(
        'WindowScope found no enclosing scope. An element window resolves against '
        'its scene — wrap the tree in a VideoScope (or Video) and a SceneScope (or Scene).',
      );
    }
    final scoped = TimeScopeProvider(scope: elementScopeFor(window, scene), child: child);
    final range = window;
    return range == null ? scoped : _WindowCarrier(range: range, child: scoped);
  }
}

/// The private inherited carrier behind [WindowScope.maybeWindowOf]: mounted
/// only when the scope has a window, so absence means "whole scene".
final class _WindowCarrier extends InheritedWidget {
  const _WindowCarrier({required this.range, required super.child});

  /// The raw, unresolved window of the enclosing element.
  final TimeRange range;

  @override
  bool updateShouldNotify(_WindowCarrier oldWidget) => oldWidget.range != range;
}
