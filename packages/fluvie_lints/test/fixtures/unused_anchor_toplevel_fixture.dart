// Fixture for the unused_anchor unit test: a top-level unused anchor. The
// stand-in `Anchor` keeps the file resolvable on its own.

class Anchor {
  Anchor([this.name]);
  final String? name;
}

// Top-level, declared and never referenced: flagged, and removable by the fix.
final topOrphan = Anchor('topOrphan');
