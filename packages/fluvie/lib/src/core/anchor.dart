/// A typed handle that names an element's timeline so triggers can reference
/// it — no strings, so autocomplete, rename-refactor, and "find usages" work.
///
/// Attach an anchor where you declare an element, then chain off it:
///
/// ```dart
/// final intro = Anchor('intro');
///
/// Text('Title').animate([Animation.pop()], anchor: intro);
/// Text('Subtitle').animate([Animation.fadeIn(at: Trigger.after(intro))]);
/// ```
///
/// An anchor is a **token**: equality is reference identity, never value
/// equality. Two `Anchor('x')` are distinct handles naming distinct timelines
/// — this is load-bearing for the trigger resolver, which keys its dependency
/// graph by anchor instance. For the same reason the constructor is
/// deliberately non-`const`: const canonicalization would silently merge
/// equal-looking anchors.
final class Anchor {
  /// Creates a fresh, unique anchor, optionally tagged with [debugName].
  Anchor([this.debugName]);

  /// A label used only in diagnostics (timeline dumps, error messages).
  ///
  /// It carries no semantic weight: anchors with the same name are still
  /// distinct, and an unnamed anchor works exactly like a named one.
  final String? debugName;

  @override
  String toString() =>
      debugName == null ? 'Anchor#${identityHashCode(this)}' : 'Anchor($debugName)';
}
