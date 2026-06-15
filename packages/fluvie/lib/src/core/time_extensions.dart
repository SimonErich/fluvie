import 'package:fluvie/src/core/time.dart';

/// Numeric sugar for building [Time] values:
///
/// ```dart
/// 20.frames        // Time.frames(20)
/// 2.5.seconds      // Time.seconds(2.5)
/// 500.ms           // Time.ms(500)
/// 0.3.relative     // Time.relative(0.3)
/// ```
extension TimeNum on num {
  /// This number as an exact, fps-independent [FrameTime] frame count.
  ///
  /// The receiver must be integral: `20.frames` is fine, `2.5.frames`
  /// asserts — there is no half frame. Use [seconds] or [ms] for real time.
  FrameTime get frames {
    assert(this % 1 == 0, 'A frame count must be integral, got $this. Use .seconds or .ms.');
    return FrameTime(toInt());
  }

  /// This number as wall-clock [SecondTime] seconds.
  SecondTime get seconds => SecondTime(toDouble());

  /// This number as whole wall-clock [MsTime] milliseconds.
  ///
  /// The receiver must be integral: for fractional values use [seconds].
  MsTime get ms {
    assert(this % 1 == 0, 'A millisecond count must be integral, got $this. Use .seconds.');
    return MsTime(toInt());
  }

  /// This number as a [RelativeTime] fraction of the enclosing window
  /// (uncapped; use [Time.relative] directly to pass a `max:` cap).
  RelativeTime get relative => RelativeTime(toDouble());
}
