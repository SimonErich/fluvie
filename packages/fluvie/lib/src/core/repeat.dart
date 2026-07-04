import 'package:fluvie/src/core/time.dart';
import 'package:meta/meta.dart';

/// How an animation loops inside its resolved span.
///
/// Repeat is presentation, not placement: the timing resolver keeps the
/// animation's single resolved span (so chaining via `Trigger.previous` and
/// `Trigger.whenEnds` stays stable), and the runner replays cycles *inside* it.
/// A `during` animation loops across its window; on enter/exit phases the
/// span stays one cycle long, so extra cycles never render.
///
/// ```dart
/// Animation.pulse(repeat: const Repeat.forever(yoyo: true));
/// Animation.spin(repeat: const Repeat.times(2, gap: Time.frames(6)));
/// ```
@immutable
final class Repeat {
  /// Plays exactly [count] cycles, then holds the final endpoint.
  ///
  /// [count] must be at least `1`. With [yoyo], every odd cycle plays in
  /// reverse; [gap] holds the just-reached endpoint between cycles.
  const Repeat.times(int this.count, {this.yoyo = false, this.gap = Time.zero})
    : assert(count >= 1, 'Repeat.times count must be >= 1');

  /// Loops for as long as the animation's span lasts.
  ///
  /// With [yoyo], every odd cycle plays in reverse. Forever-loops have no
  /// gap: [gap] is fixed at [Time.zero].
  const Repeat.forever({this.yoyo = false}) : count = null, gap = Time.zero;

  /// How many cycles to play, or `null` for [Repeat.forever].
  final int? count;

  /// Whether odd cycles play in reverse (back-and-forth motion).
  final bool yoyo;

  /// The pause between cycles, holding the just-reached endpoint.
  final Time gap;

  /// Whether this repeat loops until the span ends ([count] is `null`).
  bool get isForever => count == null;

  @override
  bool operator ==(Object other) =>
      other is Repeat && other.count == count && other.yoyo == yoyo && other.gap == gap;

  @override
  int get hashCode => Object.hash(Repeat, count, yoyo, gap);

  @override
  String toString() {
    if (isForever) return yoyo ? 'Repeat.forever(yoyo: true)' : 'Repeat.forever()';
    final parts = <String>[
      '$count',
      if (yoyo) 'yoyo: true',
      if (gap != Time.zero) 'gap: $gap',
    ];
    return 'Repeat.times(${parts.join(', ')})';
  }
}
