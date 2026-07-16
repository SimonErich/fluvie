import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/widgets.dart';
import 'package:fluvie_presenter/src/stepping/stop.dart';
import 'package:fluvie_presenter/src/stepping/stop_state.dart';

/// Carries the per-[Stop] step states down the slide's tree.
///
/// The slide view mounts one of these above the scene with a state for every
/// `Stop` the compiler discovered, keyed by widget instance (the authored
/// scene is reused across builds, so instances are stable). A `Stop` with no
/// entry presents as a passthrough — the honest fallback for a stop the
/// static walk could not see.
final class StepScope extends InheritedWidget {
  /// Provides [states] to every descendant of [child].
  const StepScope({required this.states, required super.child, super.key});

  /// The state of each discovered `Stop`, keyed by instance.
  final Map<Stop, StopState> states;

  /// The state assigned to [stop], or `null` when the enclosing scope has no
  /// entry for it (or when there is no scope at all — a plain fluvie render).
  static StopState? stateOf(BuildContext context, Stop stop) =>
      context.dependOnInheritedWidgetOfExactType<StepScope>()?.states[stop];

  @override
  bool updateShouldNotify(StepScope oldWidget) => !mapEquals(oldWidget.states, states);
}
