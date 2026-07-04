/// @docImport 'package:flutter/widgets.dart';
library;

import 'package:flutter/animation.dart' show Curve;
import 'package:flutter/widgets.dart' show Alignment, AlignmentGeometry;
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:meta/meta.dart';

/// The kind of camera move a [Camera] performs.
enum _CameraKind {
  /// No move: the scene paints at scale `1.0`, focal centre.
  still,

  /// Zooms in, scale `1` -> `zoom` about a fixed focal point.
  push,

  /// Zooms out, scale `zoom` -> `1` about a fixed focal point.
  pull,

  /// Holds a constant `zoom` while the focal point lerps `from` -> `to`.
  pan,
}

/// A scene-wide camera move: a [Transform.scale] driven by the
/// scene clock, applied *outside* every element transform but inside the
/// compositor's blend.
///
/// A camera is per-scene value data — pass one to `Scene(camera:)`. It is
/// `const`, value-equal, and frame-free; the runtime [poseAt] turns an eased
/// progress `q` (`0` at the scene start, `1` after `over`) into the concrete
/// `(scale, focal)` pose the layer mounts. The pose **holds** after `over`.
///
/// ```dart
/// Scene(duration: 4.seconds, camera: Camera.push(zoom: 1.25))
/// ```
///
/// Micro-defaults are golden-pinned and changeable before 1.0: `zoom = 1.2`,
/// the focal alignment is `Alignment.center`, `over = 1.0.relative` (the whole
/// scene), and the curve is [Ease.linear] — a camera scrub at constant speed,
/// because acceleration reads as a glitch.
@immutable
final class Camera {
  const Camera._({
    required this.over,
    required this.ease,
    required this._kind,
    required double zoom,
    required this._focalA,
    required this._focalB,
  }) : _zoom = zoom,
       assert(
         zoom >= 1,
         'A Camera zoom must be >= 1 — the camera only ever magnifies; use '
         'push/pull to choose the direction.',
       );

  /// A camera that does not move: the scene paints unscaled, centred.
  // coverage:ignore-line const ctor artifact still pose behavior pinned by camera_test
  const Camera.still()
    : this._(
        over: const Time.relative(1),
        ease: Ease.linear,
        kind: _CameraKind.still,
        zoom: 1,
        focalA: Alignment.center,
        focalB: Alignment.center,
      );

  /// Zooms *in* from scale `1` to [zoom] about the fixed [toward] focal point,
  /// easing over [over] (a fraction of the scene by default) then holding.
  const Camera.push({
    double zoom = 1.2,
    Alignment toward = Alignment.center,
    Time over = const Time.relative(1),
    Curve ease = Ease.linear,
  }) : this._(
         over: over,
         ease: ease,
         kind: _CameraKind.push,
         zoom: zoom,
         focalA: toward,
         focalB: toward,
       );

  /// Zooms *out* from [zoom] back to scale `1` about the fixed [from] focal
  /// point, easing over [over] then holding.
  const Camera.pull({
    double zoom = 1.2,
    Alignment from = Alignment.center,
    Time over = const Time.relative(1),
    Curve ease = Ease.linear,
  }) : this._(
         over: over,
         ease: ease,
         kind: _CameraKind.pull,
         zoom: zoom,
         focalA: from,
         focalB: from,
       );

  /// Holds a constant [zoom] (>= 1) while the focal point lerps [from] -> [to],
  /// easing over [over] then holding.
  const Camera.pan({
    required Alignment from,
    required Alignment to,
    double zoom = 1.2,
    Time over = const Time.relative(1),
    Curve ease = Ease.linear,
  }) : this._(
         over: over,
         ease: ease,
         kind: _CameraKind.pan,
         zoom: zoom,
         focalA: from,
         focalB: to,
       );

  /// How long the move takes, measured from the scene start. A relative time
  /// resolves against the scene scope, so `1.0.relative` spans the whole scene.
  final Time over;

  /// The curve the move eases along; [Ease.linear] by default.
  final Curve ease;

  final _CameraKind _kind;
  final double _zoom;
  final Alignment _focalA;
  final Alignment _focalB;

  /// The `(scale, focal)` pose at eased progress [q] (clamped `0..1`).
  ///
  /// - `still` is the identity `(1.0, center)` at every [q].
  /// - `push` lerps scale `1 -> zoom` about the fixed focal point.
  /// - `pull` lerps scale `zoom -> 1` about the fixed focal point.
  /// - `pan` holds `zoom` while the focal lerps `from -> to`.
  ({double scale, Alignment focal}) poseAt(double q) => switch (_kind) {
    _CameraKind.still => (scale: 1.0, focal: Alignment.center),
    _CameraKind.push => (scale: 1 + (_zoom - 1) * q, focal: _focalA),
    _CameraKind.pull => (scale: _zoom - (_zoom - 1) * q, focal: _focalA),
    _CameraKind.pan => (scale: _zoom, focal: _lerpFocal(q)),
  };

  Alignment _lerpFocal(double q) {
    final AlignmentGeometry lerped = Alignment.lerp(_focalA, _focalB, q)!;
    return lerped as Alignment;
  }

  @override
  bool operator ==(Object other) =>
      other is Camera &&
      other._kind == _kind &&
      other._zoom == _zoom &&
      other._focalA == _focalA &&
      other._focalB == _focalB &&
      other.over == over &&
      other.ease == ease;

  @override
  int get hashCode => Object.hash(Camera, _kind, _zoom, _focalA, _focalB, over, ease);

  @override
  String toString() => switch (_kind) {
    _CameraKind.still => 'Camera.still()',
    _CameraKind.push => 'Camera.push(zoom: $_zoom, toward: $_focalA, over: $over)',
    _CameraKind.pull => 'Camera.pull(zoom: $_zoom, from: $_focalA, over: $over)',
    _CameraKind.pan => 'Camera.pan(from: $_focalA, to: $_focalB, zoom: $_zoom, over: $over)',
  };
}
