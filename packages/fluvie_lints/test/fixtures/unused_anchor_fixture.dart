// Fixture for the unused_anchor unit test. `Anchor` is referenced by name only,
// so the fixture defines a local stand-in to keep the file resolvable.
// ignore_for_file: unused_local_variable, unused_field

class Anchor {
  Anchor([this.name]);
  final String? name;
}

class Trigger {
  Trigger.after(Anchor a);
}

// A class field anchor never referenced in this file is NOT flagged: a field can
// be referenced from another file, which the single-file rule cannot see.
class Banner {
  final fieldAnchor = Anchor('field');
}

void build() {
  // Declared and never referenced again: flagged.
  final orphan = Anchor('orphan');

  // Declared and referenced by a Trigger: not flagged.
  final intro = Anchor('intro');
  Trigger.after(intro);
}
