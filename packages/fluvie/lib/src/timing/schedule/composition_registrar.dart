/// @docImport 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
library;

import 'package:fluvie/src/timing/schedule/element_registration.dart';
import 'package:fluvie/src/timing/schedule/element_schedule.dart';

/// The composition-level schedule contract: elements register themselves during
/// build and receive their resolved [ElementSchedule] back by lookup once the
/// whole composition has been resolved.
///
/// Lives in `timing/schedule/` so the animation layer can consume it without
/// importing `composition/`: the contract speaks only plan-level types. The
/// protocol is two-pass:
///
/// 1. **Collect** — during the first build every element calls [register] and
///    receives `null`; the registrar appends the token in build order.
/// 2. **Resolved** — after the composition resolves once, [register] with a
///    known token returns its schedule (the call doubles as the per-frame
///    lookup); an **unknown** token throws a [FluvieTimingError], because the
///    element set must be stable across frames.
abstract interface class CompositionRegistrar {
  /// Registers [registration] (idempotent per token) and returns its resolved
  /// schedule, or `null` while the registrar is still collecting.
  ///
  /// Throws a [FluvieTimingError] when an unknown token arrives after
  /// resolution — build elements unconditionally and gate visibility with
  /// `.show()`, never with `if`.
  ElementSchedule? register(ElementRegistration registration);

  /// Forgets [registration] — called when the registering element unmounts.
  ///
  /// Disposal merely unregisters: the token's resolved schedule survives the
  /// current generation, so a remounting element re-registers the same token
  /// without error. Unknown tokens are ignored.
  void unregister(ElementRegistration registration);

  /// Whether the composition has resolved — `false` while collecting and
  /// after a reset.
  ///
  /// Elements consult this when their timing-relevant fields change: before
  /// resolution the token is rebuilt silently, after it the change is a
  /// determinism violation and throws.
  bool get isResolved;
}
