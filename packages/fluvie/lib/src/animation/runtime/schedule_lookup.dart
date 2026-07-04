/// @docImport 'package:fluvie/src/animation/runtime/registrar_binding.dart';
/// @docImport 'package:fluvie/src/timing/schedule/resolved_schedule_scope.dart';
library;

import 'package:fluvie/src/timing/schedule/element_schedule.dart';

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
