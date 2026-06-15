/// @docImport 'package:fluvie/src/core/time.dart';
/// @docImport 'package:fluvie/src/timing/scene_scope.dart';
/// @docImport 'package:fluvie/src/timing/video_scope.dart';
library;

import 'package:flutter/widgets.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

/// Carries the nearest [TimeScopeData] down the tree.
///
/// Every level that defines a duration mounts one of these: [VideoScope] at
/// the root, [SceneScope] per scene, and any element with its own window.
/// Descendants read the nearest scope with [of] and resolve
/// symbolic [Time] values against it — no frame numbers at the call site.
final class TimeScopeProvider extends InheritedWidget {
  /// Provides [scope] to every descendant of [child].
  const TimeScopeProvider({required this.scope, required super.child, super.key});

  /// The scope visible to this subtree.
  final TimeScopeData scope;

  /// The nearest scope above [context].
  ///
  /// Throws a [FluvieTimingError] when there is none — symbolic times cannot
  /// resolve outside a [VideoScope].
  static TimeScopeData of(BuildContext context) {
    final scope = maybeOf(context);
    if (scope == null) {
      throw FluvieTimingError(
        'No TimeScope found above this context. Wrap the subtree in a VideoScope '
        '(directly or via Video) so Time values can resolve to frames.',
      );
    }
    return scope;
  }

  /// The nearest scope above [context], or `null` when there is none.
  static TimeScopeData? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TimeScopeProvider>()?.scope;

  @override
  bool updateShouldNotify(TimeScopeProvider oldWidget) => oldWidget.scope != scope;
}
