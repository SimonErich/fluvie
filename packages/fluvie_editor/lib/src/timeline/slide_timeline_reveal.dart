part of 'slide_timeline_model.dart';

/// The element types whose content animates over an intrinsic `reveal` window
/// rather than an `.animate()` entry: a counter counts up, a chart grows, a
/// diagram or annotation draws on, code and markdown type in. That timing is
/// modeled nowhere the timeline sees, so a read-only bar surfaces it.
const Set<String> _revealTypes = {
  'Counter',
  'Chart',
  'Markdown',
  'Shape',
  'Arrow',
  'Connector',
  'LowerThird',
  'TitleCard',
  'Spotlight',
  'Code',
  'Mermaid',
};

/// The reveal window [type] carries in its `reveal` value, or `null` when the
/// type reveals nothing (not reveal-bearing, no `reveal` authored, or an
/// instant reveal).
///
/// A plain reveal is a single unit-tagged `Time` string (`"2s"`). Code and
/// Mermaid instead carry a tagged union whose one timed field — a `window`, a
/// glyph `speed`, or a per-line pace — is the window this reads; `instant`
/// and `none` carry no field and reveal at once.
Time? _revealTime(Object? type, Object? reveal) {
  if (reveal == null || !_revealTypes.contains(type)) return null;
  if (reveal is String) return decodeTime(reveal);
  if (reveal is Map<String, Object?>) {
    final field = reveal['window'] ?? reveal['speed'] ?? reveal['perLine'];
    return field == null ? null : decodeTime(field);
  }
  return null; // coverage:ignore-line a reveal type carries a time string or a union map
}

/// The read-only reveal bars: a counter, chart, diagram, annotation, code, or
/// markdown element animates its content over its own `reveal` window, which
/// no `animate` entry models — so one display-only bar shows that window.
extension _RevealBars on _ModelBuilder {
  /// The reveal bar for [id], or `null` when the element reveals nothing.
  ///
  /// The bar spans the reveal window from the element scope start, made
  /// slide-relative. It registers no binding: an intrinsic reveal cannot be
  /// retimed from the timeline, so the panel routes a tap on it to a plain
  /// selection instead.
  TimelineBar? revealBar(String id, Map<String, Object?> json, ElementIntrospection? element) {
    final reveal = _revealTime(json['type'], json['reveal']);
    if (reveal == null) return null;
    final fps = document.spec.fps;
    final scope = element == null ? _SceneScope(fps, sceneFrames) : _WindowScope(fps, element);
    final revealFrames = reveal.resolveFrames(scope);
    if (revealFrames <= 0) return null;
    final start = element == null ? 0 : element.window.start - sceneStart;
    return TimelineBar(
      id: '$id:reveal',
      start: start.toDouble(),
      end: (start + revealFrames).toDouble(),
      color: palette.during,
      badge: 'reveal',
    );
  }
}

/// Resolves an authored [`Time`] against an element's own alive window — what
/// a relative delay or reveal means, and a no-op for absolute units.
final class _WindowScope implements TimeScope {
  const _WindowScope(this.fps, this.element);

  @override
  final int fps;

  final ElementIntrospection element;

  // coverage:ignore-line TimeScope obligation never read by tail or reveal resolution
  @override
  int get startFrame => element.window.start;

  @override
  int get durationFrames => element.window.durationFrames;

  // coverage:ignore-line TimeScope obligation resolution uses the nearest scope only
  @override
  TimeScope? get parent => null;
}

/// Resolves an authored [`Time`] against the whole slide — the scope a bare
/// reveal element (one with no `.animate()` wrapper, so no introspection)
/// measures against, exactly as its runtime scope would.
final class _SceneScope implements TimeScope {
  const _SceneScope(this.fps, this.durationFrames);

  @override
  final int fps;

  @override
  final int durationFrames;

  // coverage:ignore-line TimeScope obligation never read by reveal resolution
  @override
  int get startFrame => 0;

  // coverage:ignore-line TimeScope obligation resolution uses the nearest scope only
  @override
  TimeScope? get parent => null;
}
