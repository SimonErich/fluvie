import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart' show FrameProvider;

/// Rebases the frame clock for a subtree: the enclosing frame `f` is
/// republished as `max(0, f - baseFrame) + skipFrames`.
///
/// This is how revealed step content plays its authored entrance from the
/// moment it appeared: the subtree's clock starts at zero (plus the settle
/// offset) at the reveal frame and keeps advancing with the slide clock, so
/// entrances play once and ambient loops never pause.
final class FrameRebase extends StatelessWidget {
  /// Republishes the enclosing frame rebased to [baseFrame], offset by
  /// [skipFrames].
  const FrameRebase({required this.baseFrame, required this.child, this.skipFrames = 0, super.key});

  /// The enclosing-clock frame the subtree's frame zero maps to.
  final int baseFrame;

  /// A constant offset added after rebasing — the settle skip.
  final int skipFrames;

  /// The subtree living on the rebased clock.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final frame = FrameProvider.of(context).frame;
    return FrameProvider(frame: math.max(0, frame - baseFrame) + skipFrames, child: child);
  }
}
