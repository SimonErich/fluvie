// Fixture for the cyclic_trigger unit test. Local stand-ins keep the file
// resolvable; the rule reads the syntax.
// ignore_for_file: unused_local_variable

class Anchor {
  Anchor([this.name]);
  final String? name;
}

class Animation {
  Animation.fadeIn({Trigger? at});
}

class Trigger {
  static Trigger whenEnds(Anchor a) => Trigger();
  Trigger();
}

class Element {
  Element animate(List<Animation> a, {Anchor? anchor}) => this;
}

void build() {
  final a = Anchor('a');
  final b = Anchor('b');
  final c = Anchor('c');

  // A waits for B and B waits for A: a two-node cycle. Both flagged.
  Element().animate([Animation.fadeIn(at: Trigger.whenEnds(b))], anchor: a);
  Element().animate([Animation.fadeIn(at: Trigger.whenEnds(a))], anchor: b);

  // C waits for A only: an acyclic dependency, not flagged.
  Element().animate([Animation.fadeIn(at: Trigger.whenEnds(a))], anchor: c);
}
