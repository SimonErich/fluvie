/// @docImport 'package:fluvie/src/animation/motion_target.dart';
library;

import 'package:flutter/widgets.dart' show BuildContext;
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/animation/runtime/animation_plan_adapter.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/timing/schedule/composition_registrar.dart';
import 'package:fluvie/src/timing/schedule/composition_registrar_scope.dart';
import 'package:fluvie/src/timing/schedule/element_registration.dart';
import 'package:fluvie/src/timing/schedule/element_schedule.dart';
import 'package:fluvie/src/timing/schedule/resolved_schedule_scope.dart';
import 'package:fluvie/src/timing/window_scope.dart';

/// One element's registrar-side state, owned by its [MotionTarget] State for
/// the State's lifetime: the registration token, the registrar it registered
/// with, and the consult-order lookup.
///
/// The token is built once, on the first build under a registrar:
/// `window = widget.window ?? WindowScope.maybeWindowOf(context)`, so a
/// window-less target nested inside a shown (windowed) subtree inherits the
/// enclosing window and its animations place inside it (the windowed
/// target must enclose the animated one in the tree). An explicit window
/// nested inside another explicit window resolves against the **scene**;
/// window-relative nesting remains a local-fallback-only behavior outside
/// `Video`.
final class RegistrarBinding {
  ElementRegistration? _token;
  CompositionRegistrar? _registrar;
  bool _staleAfterResolution = false;

  /// Whether this element has bound to a registrar — `true` from the first
  /// collect-pass registration on. The target then keeps its child subtree
  /// behind a `GlobalKey`, so the pass-1 → pass-2 (and frame-boundary)
  /// wrapper-shape changes reparent nested registrations instead of
  /// remounting them.
  bool get isBound => _registrar != null;

  /// Resolves the schedule per the consult order: an explicit
  /// [ResolvedScheduleScope] (tests/embedding, nearest-wins) beats the
  /// registrar, which beats nothing — [Standalone] tells the caller to fall
  /// back to local resolution.
  ///
  /// Under a collecting registrar this registers the element's token
  /// (idempotently) and returns [CollectPending]; once resolved, the same
  /// call is the per-frame schedule lookup.
  ScheduleLookup lookup(
    BuildContext context, {
    required List<Animation> animations,
    required Anchor? anchor,
    required TimeRange? window,
    required Defaults? defaults,
    required Type childType,
  }) {
    if (_staleAfterResolution) {
      throw FluvieTimingError(
        "The timing-relevant fields of '${_token?.debugOwner ?? '$childType'}' "
        'changed after its composition resolved — the resolver must see '
        'identical input every frame (the determinism contract). Keep '
        'animations, window, defaults, and anchor stable, or remount the '
        'Video to re-resolve.',
      );
    }
    final explicit = ResolvedScheduleScope.maybeOf(context);
    if (explicit != null) return ScheduleReady(explicit);
    final registrar = CompositionRegistrarScope.maybeOf(context);
    if (registrar == null) return const Standalone();
    _registrar = registrar;
    final token = _token ??= ElementRegistration(
      debugOwner: anchor?.debugName ?? '$childType',
      anchor: anchor,
      window: window ?? WindowScope.maybeWindowOf(context),
      animations: [for (final animation in animations) toAnimationPlan(animation)],
      defaults: defaults,
    );
    final schedule = registrar.register(token);
    return schedule == null ? const CollectPending() : ScheduleReady(schedule);
  }

  /// Reacts to a timing-relevant widget-field change: **after** the
  /// composition resolved this is a determinism violation — recorded here
  /// and thrown from the next [lookup] (a `didUpdateWidget` cannot throw
  /// without corrupting the framework's update walk). While still collecting
  /// (or after a `Video` reset) the stale token is dropped so the next build
  /// re-registers from the new fields.
  void didChangeTimingFields() {
    final token = _token;
    final registrar = _registrar;
    if (token == null || registrar == null) return;
    if (registrar.isResolved) {
      _staleAfterResolution = true;
      return;
    }
    registrar.unregister(token);
    _token = null;
  }

  /// Unregisters on element unmount: disposal merely unregisters — the
  /// schedule survives in the registrar, so a remount of the same token is
  /// not an error.
  void dispose() {
    final token = _token;
    if (token != null) _registrar?.unregister(token);
    _token = null;
    _registrar = null;
  }
}

/// The outcome of one [RegistrarBinding.lookup] — which arm of the
/// consult order applies this build.
sealed class ScheduleLookup {
  const ScheduleLookup();
}

/// A schedule is available: an explicit [ResolvedScheduleScope] or a resolved
/// registrar answered — render the full animated frame with it.
final class ScheduleReady extends ScheduleLookup {
  /// Wraps the [schedule] to render with.
  const ScheduleReady(this.schedule);

  /// The element's resolved schedule.
  final ElementSchedule schedule;
}

/// A registrar is still collecting (pass 1): render the hidden
/// placeholder — no animation math, layout slot held.
final class CollectPending extends ScheduleLookup {
  /// Const marker.
  const CollectPending();
}

/// No explicit scope and no registrar: standalone mode — the caller resolves
/// a local schedule (the documented fallback).
final class Standalone extends ScheduleLookup {
  /// Const marker.
  const Standalone();
}
