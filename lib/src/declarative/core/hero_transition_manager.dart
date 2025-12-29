import 'package:flutter/widgets.dart';

/// Manages hero-style transitions between elements with matching GlobalKeys.
///
/// [HeroTransitionManager] tracks elements across scenes and automatically
/// generates smooth transitions for elements that share the same GlobalKey.
///
/// This is used internally by [Video] to enable automatic hero animations.
///
/// Example:
/// ```dart
/// // In Scene 1
/// VPositioned(
///   heroKey: GlobalKey(), // Same key in both scenes
///   left: 100,
///   top: 200,
///   child: Image.asset('photo.jpg'),
/// )
///
/// // In Scene 2 - element will animate from Scene 1's position
/// VPositioned(
///   heroKey: sameGlobalKey, // Same key
///   left: 500,
///   top: 100,
///   child: Image.asset('photo.jpg'),
/// )
/// ```
class HeroTransitionManager {
  /// Registered hero elements by key.
  final Map<GlobalKey, List<_HeroRegistration>> _registrations = {};

  /// Registers an element for hero transitions.
  void registerElement({
    required GlobalKey key,
    required int sceneIndex,
    required Rect bounds,
    double? rotation,
    double? scale,
  }) {
    _registrations.putIfAbsent(key, () => []);
    _registrations[key]!.add(
      _HeroRegistration(
        sceneIndex: sceneIndex,
        bounds: bounds,
        rotation: rotation ?? 0.0,
        scale: scale ?? 1.0,
      ),
    );

    // Sort by scene index
    _registrations[key]!.sort((a, b) => a.sceneIndex.compareTo(b.sceneIndex));
  }

  /// Unregisters an element.
  void unregisterElement(GlobalKey key, int sceneIndex) {
    if (_registrations.containsKey(key)) {
      _registrations[key]!.removeWhere((reg) => reg.sceneIndex == sceneIndex);
      if (_registrations[key]!.isEmpty) {
        _registrations.remove(key);
      }
    }
  }

  /// Gets the interpolated bounds for a hero element during a transition.
  ///
  /// Returns null if no transition should occur.
  HeroTransitionData? getTransitionData({
    required GlobalKey key,
    required int fromSceneIndex,
    required int toSceneIndex,
    required double progress,
  }) {
    final registrations = _registrations[key];
    if (registrations == null || registrations.length < 2) {
      return null;
    }

    // Find registrations for the transition
    _HeroRegistration? fromReg;
    _HeroRegistration? toReg;

    for (final reg in registrations) {
      if (reg.sceneIndex == fromSceneIndex) {
        fromReg = reg;
      } else if (reg.sceneIndex == toSceneIndex) {
        toReg = reg;
      }
    }

    if (fromReg == null || toReg == null) {
      return null;
    }

    // Interpolate bounds
    final bounds = Rect.lerp(fromReg.bounds, toReg.bounds, progress)!;
    final rotation = _lerpDouble(fromReg.rotation, toReg.rotation, progress);
    final scale = _lerpDouble(fromReg.scale, toReg.scale, progress);

    return HeroTransitionData(bounds: bounds, rotation: rotation, scale: scale);
  }

  /// Checks if a key has registrations in adjacent scenes.
  bool hasHeroTransition(GlobalKey key, int sceneIndex) {
    final registrations = _registrations[key];
    if (registrations == null || registrations.length < 2) {
      return false;
    }

    // Check if there's a registration in an adjacent scene
    for (final reg in registrations) {
      if (reg.sceneIndex == sceneIndex - 1 ||
          reg.sceneIndex == sceneIndex + 1) {
        return true;
      }
    }
    return false;
  }

  /// Clears all registrations.
  void clear() {
    _registrations.clear();
  }

  double _lerpDouble(double a, double b, double t) {
    return a + (b - a) * t;
  }
}

/// Internal registration data for a hero element.
class _HeroRegistration {
  final int sceneIndex;
  final Rect bounds;
  final double rotation;
  final double scale;

  const _HeroRegistration({
    required this.sceneIndex,
    required this.bounds,
    required this.rotation,
    required this.scale,
  });
}

/// Data for a hero transition at a specific progress point.
class HeroTransitionData {
  /// The interpolated bounds.
  final Rect bounds;

  /// The interpolated rotation in radians.
  final double rotation;

  /// The interpolated scale.
  final double scale;

  const HeroTransitionData({
    required this.bounds,
    required this.rotation,
    required this.scale,
  });
}
