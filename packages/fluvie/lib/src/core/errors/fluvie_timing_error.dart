import 'package:fluvie/src/core/anchor.dart';

/// A build-time timing failure: a trigger cycle, a dangling anchor reference,
/// a missing scope, or any other plan the resolver cannot turn into frames.
///
/// Fluvie throws this *before* rendering, never mid-capture — timing
/// resolution is a pure pre-pass, so a bad plan fails fast with an actionable
/// message instead of hanging or producing a broken video. The [anchors]
/// involved (for example, both ends of a cycle) are named in [toString] so
/// the offending declarations are easy to find.
///
/// This is a pure exception in `core` (not `diagnostics`): every layer above
/// may throw and catch it without violating the layering law.
final class FluvieTimingError implements Exception {
  /// Creates a timing error described by [message], optionally naming the
  /// [anchors] involved.
  FluvieTimingError(this.message, {this.anchors = const []});

  /// What went wrong, in one actionable sentence.
  final String message;

  /// The anchors involved in the failure, in diagnostic order (for a cycle:
  /// the participants in declaration order). Empty when no anchor applies.
  final List<Anchor> anchors;

  @override
  String toString() {
    if (anchors.isEmpty) return 'FluvieTimingError: $message';
    final names = anchors.map(_anchorName).join(', ');
    return 'FluvieTimingError: $message (anchors: $names)';
  }

  /// The anchor's [Anchor.debugName], or `Anchor#<identityHashCode>` when it
  /// has none — matching [Anchor.toString]'s unnamed form.
  static String _anchorName(Anchor anchor) =>
      anchor.debugName ?? 'Anchor#${identityHashCode(anchor)}';
}
