// Fixture for the conflicting_keyframe_fields unit test. Local stand-ins model
// the fluvie surface so the rule reads the literal syntax.
// ignore_for_file: unused_local_variable

class Trigger {
  static const Trigger auto = Trigger._();
  const Trigger._();
}

class Keyframe {
  const Keyframe({this.opacity, this.scale});
  final double? opacity;
  final double? scale;
}

class Animation {
  Animation.from(Keyframe from, {Trigger? at});
  Animation.to(Keyframe to, {Trigger? at});
}

class Element {
  Element animate(List<Animation> a) => this;
}

void build() {
  // Two full-window writes of `opacity`: both flagged.
  Element().animate([
    Animation.from(const Keyframe(opacity: 0)),
    Animation.to(const Keyframe(opacity: 1)),
  ]);

  // Different fields (opacity vs scale): no conflict.
  Element().animate([
    Animation.from(const Keyframe(opacity: 0)),
    Animation.to(const Keyframe(scale: 2)),
  ]);

  // Same field but one carries an explicit at:: sequenced, not flagged.
  Element().animate([
    Animation.from(const Keyframe(opacity: 0)),
    Animation.to(const Keyframe(opacity: 1), at: Trigger.auto),
  ]);
}
