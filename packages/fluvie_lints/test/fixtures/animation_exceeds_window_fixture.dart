// Fixture for the animation_exceeds_window unit test. Local stand-ins model the
// fluvie time/animation surface so the rule reads the literal syntax.
// ignore_for_file: unused_local_variable

class Time {}

class TimeRange {}

extension TimeNum on num {
  Time get frames => Time();
  Time get seconds => Time();
}

extension RangeStart on Time {
  TimeRange to(Time end) => TimeRange();
}

class Animation {
  Animation.fadeIn({Time? duration});
}

class Element {
  Element animate(List<Animation> a, {TimeRange? window}) => this;
}

void build() {
  // Duration 90 frames over a 60-frame window: exceeds, flagged.
  Element().animate(
    [Animation.fadeIn(duration: 90.frames)],
    window: 0.frames.to(60.frames),
  );

  // Duration 30 frames over a 60-frame window: fits, not flagged.
  Element().animate(
    [Animation.fadeIn(duration: 30.frames)],
    window: 0.frames.to(60.frames),
  );

  // Mixed units (seconds vs frames): not statically comparable, silent.
  Element().animate(
    [Animation.fadeIn(duration: 5.seconds)],
    window: 0.frames.to(60.frames),
  );

  // Same unit, double literals: 2.5s over a 1.0s window exceeds, flagged.
  Element().animate(
    [Animation.fadeIn(duration: 2.5.seconds)],
    window: 0.0.seconds.to(1.0.seconds),
  );
}
