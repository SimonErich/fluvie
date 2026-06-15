import 'package:flutter/widgets.dart' show Widget;
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/animation/motion_target.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:meta/meta.dart' show useResult;

/// The one mechanism for motion: works on any widget, Fluvie's or Flutter's.
///
/// ```dart
/// Text('Only the middle third')
///     .show(from: 0.33.relative, to: 0.66.relative)
///     .animate([Animation.fadeIn(), Animation.fadeOut()]);
/// ```
extension Animate on Widget {
  /// Binds [animations] to this widget by wrapping it in a [MotionTarget].
  ///
  /// [anchor] names this element's timeline for other elements' triggers,
  /// [window] overrides its alive-window (default: the whole scene), and
  /// [defaults] merges over the inherited cascade.
  @useResult
  Widget animate(
    List<Animation> animations, {
    Anchor? anchor,
    TimeRange? window,
    Defaults? defaults,
  }) => MotionTarget(
    animations: animations,
    anchor: anchor,
    window: window,
    defaults: defaults,
    child: this,
  );

  /// Visibility-window sugar: `animate([], window: from.to(to))` with [from]
  /// defaulting to the window start and [to] to its end.
  ///
  /// Both bounds `null` means the whole scene, so no window is mounted at
  /// all — `show()` alone changes nothing.
  @useResult
  Widget show({Time? from, Time? to}) => animate(
    const [],
    window: from == null && to == null
        ? null
        : (from ?? Time.zero).to(to ?? const Time.relative(1)),
  );
}
