// Fixture for the dangling_anchor unit test. Local stand-ins keep the file
// resolvable; the rule reads the syntax, not the real fluvie types.
// ignore_for_file: unused_local_variable

class Anchor {
  Anchor([this.name]);
  final String? name;
}

class Trigger {
  static Trigger whenEnds(Anchor a) => Trigger();
  static Trigger whenStarts(Anchor a) => Trigger();
  Trigger();
}

class Element {
  Element animate(List<Object> a, {Anchor? anchor}) => this;
}

void build() {
  // Waited on but never attached in this body: dangling.
  final ghost = Anchor('ghost');
  Trigger.whenEnds(ghost);

  // Waited on AND attached via anchor:: not dangling.
  final intro = Anchor('intro');
  Element().animate(<Object>[], anchor: intro);
  Trigger.whenStarts(intro);
}
