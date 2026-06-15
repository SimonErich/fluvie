/// @docImport 'package:fluvie/src/composition/runtime/video_plan_builder.dart';
library;

import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/timing/schedule/composition_registrar.dart';
import 'package:fluvie/src/timing/schedule/element_registration.dart';
import 'package:fluvie/src/timing/schedule/element_schedule.dart';

/// The mutable registrar a `Video`'s State owns: collects element tokens per
/// scene during the first build, stores the schedules [buildVideoPlan]
/// resolved, and answers per-frame lookups afterwards.
///
/// Elements never see this type — they consume the [CompositionRegistrar]
/// contract through the per-scene [forScene] facade, which tags every
/// registration with its scene index. Each [forScene] call returns a **fresh**
/// facade on purpose: `Video` mounts it in a `CompositionRegistrarScope`
/// whose identity-based `updateShouldNotify` then rebuilds every element
/// after [resolveWith] (the deferred second pass).
final class VideoRegistrar {
  /// Creates a collecting registrar for [sceneCount] scenes.
  VideoRegistrar({required int sceneCount})
    : _registrations = [for (var s = 0; s < sceneCount; s++) []];

  final List<List<ElementRegistration>> _registrations;
  final Map<ElementRegistration, ElementSchedule> _schedules = {};
  final Map<ElementRegistration, int> _sceneOf = {};
  bool _resolved = false;

  /// Whether [resolveWith] has run for the current collect generation.
  bool get isResolved => _resolved;

  /// The collected tokens per scene, in registration order (build order) —
  /// the plan builder's input. Unmodifiable views.
  List<List<ElementRegistration>> get registrationsByScene => List.unmodifiable([
    for (final scene in _registrations) List<ElementRegistration>.unmodifiable(scene),
  ]);

  /// The [CompositionRegistrar] facade for scene [sceneIndex] — a fresh
  /// instance per call (load-bearing: see the class docs).
  CompositionRegistrar forScene(int sceneIndex) {
    assert(
      sceneIndex >= 0 && sceneIndex < _registrations.length,
      'forScene($sceneIndex) is out of range for ${_registrations.length} scenes.',
    );
    return _SceneRegistrar(this, sceneIndex);
  }

  /// Stores the resolved [schedules] (keyed by token identity) and flips the
  /// registrar into resolved mode.
  void resolveWith(Map<ElementRegistration, ElementSchedule> schedules) {
    _schedules
      ..clear()
      ..addAll(schedules);
    _resolved = true;
  }

  /// Starts a new collect generation: forgets every registration and
  /// schedule. [sceneCount] resizes the per-scene lists when the new scenes
  /// list has a different length.
  void reset({int? sceneCount}) {
    final count = sceneCount ?? _registrations.length;
    _registrations
      ..clear()
      ..addAll([for (var s = 0; s < count; s++) []]);
    _schedules.clear();
    _sceneOf.clear();
    _resolved = false;
  }

  ElementSchedule? _register(int sceneIndex, ElementRegistration registration) {
    final resolved = _schedules[registration];
    if (resolved != null) {
      _add(sceneIndex, registration); // Remount survival: re-list it.
      return resolved;
    }
    if (_resolved) {
      throw FluvieTimingError(
        "A new element ('${registration.debugOwner}') registered after this "
        'composition resolved its schedules. The element set must be stable '
        'across frames — build MotionTargets unconditionally and gate '
        'visibility with .show(), not `if`. Remount the Video to change the '
        'composition.',
      );
    }
    _add(sceneIndex, registration);
    return null;
  }

  void _add(int sceneIndex, ElementRegistration registration) {
    if (_sceneOf.containsKey(registration)) return; // Idempotent per token.
    _sceneOf[registration] = sceneIndex;
    _registrations[sceneIndex].add(registration);
  }

  void _unregister(ElementRegistration registration) {
    final sceneIndex = _sceneOf.remove(registration);
    if (sceneIndex == null) return;
    _registrations[sceneIndex].remove(registration);
    // The schedule survives: a remount re-registers the same token.
  }
}

/// The thin per-scene [CompositionRegistrar] facade [VideoRegistrar.forScene]
/// hands out.
final class _SceneRegistrar implements CompositionRegistrar {
  _SceneRegistrar(this._owner, this._sceneIndex);

  final VideoRegistrar _owner;
  final int _sceneIndex;

  @override
  bool get isResolved => _owner.isResolved;

  @override
  ElementSchedule? register(ElementRegistration registration) =>
      _owner._register(_sceneIndex, registration);

  @override
  void unregister(ElementRegistration registration) => _owner._unregister(registration);
}
