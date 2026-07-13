/// @docImport 'package:fluvie/src/composition/video.dart';
library;

import 'package:flutter/widgets.dart';
import 'package:fluvie/src/timing/schedule/composition_registrar_scope.dart';

/// Detaches its subtree from the enclosing composition's schedule: every
/// `.animate()` element below resolves locally and immediately against the
/// nearest time scope, and elements may mount or unmount at any time.
///
/// A [Video] resolves its plan once, so its element set must stay stable
/// across frames — a fresh animated element mounted after that resolve is a
/// timing error. Live consumers (players, presenters, previews) sometimes
/// need exactly that: content that appears mid-playback and animates in from
/// the moment it mounts. Wrapping the dynamic subtree in a `LocalMotionScope`
/// trades the composition-level features for that freedom:
///
/// * schedules resolve immediately (no collect pass, no hidden first frame),
/// * mounting and unmounting is free at any point of playback,
/// * cross-element triggers (`Trigger.whenEnds`/`whenStarts`) and
///   `Trigger.beat` are unavailable below it — they need the composition
///   plan. `Trigger.previous` chains on one element still work.
///
/// ```dart
/// LocalMotionScope(
///   child: bullet.animate([Animation.slideFadeIn()]),
/// )
/// ```
final class LocalMotionScope extends StatelessWidget {
  /// Detaches [child] from the enclosing composition's schedule.
  const LocalMotionScope({required this.child, super.key});

  /// The subtree whose elements resolve locally.
  final Widget child;

  @override
  Widget build(BuildContext context) => CompositionRegistrarScope.none(child: child);
}
