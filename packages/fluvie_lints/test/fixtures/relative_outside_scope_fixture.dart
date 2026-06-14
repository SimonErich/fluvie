// Fixture for the relative_outside_scope unit test. Local stand-ins model the
// scope-defining types so the rule reads the literal syntax.
// ignore_for_file: unused_local_variable

class Time {
  Time.relative(double f);
}

class Video {
  Video({required Time duration});
}

extension TimeNum on num {
  Time get relative => Time.relative(toDouble());
  Time get seconds => Time.relative(toDouble());
}

class Scene {
  Scene({required Time duration});
}

class Element {
  Element show({Time? from}) => this;
}

void build() {
  // A scene duration cannot be a fraction of itself: flagged.
  Scene(duration: 0.5.relative);

  // A concrete scene duration: fine.
  Scene(duration: 5.seconds);

  // A relative inside an element window (the scene scopes it): not flagged.
  Element().show(from: 0.3.relative);

  // A Video duration built with the Time.relative(...) constructor: flagged.
  Video(duration: Time.relative(0.5));
}
