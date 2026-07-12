import 'package:fluvie/src/core/time.dart';
import 'package:meta/meta.dart';

/// A reference to a `Timeline` label, plus a signed [offset] applied to the
/// label's recorded playhead position.
///
/// `Timeline.play(at:)` accepts a `LabelRef` so a step can place itself relative
/// to a named moment: `at: 'reveal'.label - 0.2.seconds` starts two tenths of a
/// second before the `reveal` label. The reference stays symbolic until the
/// timeline resolves its placements at the enclosing `Video`'s fps, so it
/// never reaches the per-frame hot path.
///
/// ```dart
/// 'reveal'.label            // the reveal label at its recorded position
/// 'reveal'.label + 0.2.seconds   // a fifth of a second after it
/// 'reveal'.label - 0.2.seconds   // a fifth of a second before it
/// ```
@immutable
final class LabelRef {
  /// Creates a reference to the label [name], offset by [offset]
  /// (default: [Time.zero], the label itself).
  const LabelRef(this.name, {this.offset = Time.zero});

  /// The label this reference points at — matched against the timeline's
  /// recorded `label()` calls by name.
  final String name;

  /// The signed offset from the label's recorded playhead position; positive
  /// is later, negative is earlier.
  final Time offset;

  /// This reference moved [delta] later — adds to the running [offset].
  LabelRef operator +(Time delta) => LabelRef(name, offset: offset + delta);

  /// This reference moved [delta] earlier — subtracts from the running [offset].
  LabelRef operator -(Time delta) => LabelRef(name, offset: offset - delta);

  @override
  bool operator ==(Object other) =>
      other is LabelRef && other.name == name && other.offset == offset;

  @override
  int get hashCode => Object.hash(LabelRef, name, offset);

  @override
  String toString() => 'LabelRef($name, offset: $offset)';
}

/// Call-site sugar for building a [LabelRef] from a label name.
///
/// ```dart
/// timeline.play(cta, Animation.pop(), at: 'reveal'.label - 0.2.seconds);
/// ```
extension LabelExtension on String {
  /// This string as a [LabelRef] at zero offset — the named label itself.
  LabelRef get label => LabelRef(this);
}
