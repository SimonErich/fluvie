import 'package:fluvie/fluvie.dart' show EffectSpecKind;
import 'package:meta/meta.dart';

/// One browser entry: which effect, where it sits in the browser, and one
/// sentence an author searches by.
@immutable
final class EffectCatalogEntry {
  /// Creates the entry.
  const EffectCatalogEntry(this.kind, {required this.group, required this.blurb});

  /// The effect this entry adds.
  final EffectSpecKind kind;

  /// The browser group heading it files under.
  final String group;

  /// What it does, in one searchable sentence.
  final String blurb;

  /// The document form an add lands: the kind on its own defaults, so what
  /// mounts is exactly what the spec would render for a bare declaration.
  Map<String, Object?> json() => {'kind': kind.name};
}

/// Every effect the browser offers, grouped for reading: colour first,
/// then the film-look family, then motion, then the generative pair.
const List<EffectCatalogEntry> effectCatalog = [
  EffectCatalogEntry(
    EffectSpecKind.blur,
    group: 'Film',
    blurb: 'Gaussian blur with a keyframable radius.',
  ),
  EffectCatalogEntry(
    EffectSpecKind.grade,
    group: 'Colour',
    blurb: 'Exposure, contrast, saturation, temperature and tint.',
  ),
  EffectCatalogEntry(
    EffectSpecKind.curves,
    group: 'Colour',
    blurb: 'A master tone curve and one per channel.',
  ),
  EffectCatalogEntry(
    EffectSpecKind.lut,
    group: 'Colour',
    blurb: 'A .cube 3D LUT file, applied at an intensity.',
  ),
  EffectCatalogEntry(
    EffectSpecKind.grain,
    group: 'Film',
    blurb: 'Seeded monochrome film grain over the element.',
  ),
  EffectCatalogEntry(
    EffectSpecKind.vignette,
    group: 'Film',
    blurb: 'Darkened corners drawing the eye inward.',
  ),
  EffectCatalogEntry(
    EffectSpecKind.scanlines,
    group: 'Film',
    blurb: 'Horizontal CRT lines for a broadcast look.',
  ),
  EffectCatalogEntry(
    EffectSpecKind.chromatic,
    group: 'Film',
    blurb: 'A red and blue channel split at the edges.',
  ),
  EffectCatalogEntry(
    EffectSpecKind.bloom,
    group: 'Film',
    blurb: 'An additive glow lifting the brightest parts.',
  ),
  EffectCatalogEntry(
    EffectSpecKind.glitch,
    group: 'Motion',
    blurb: 'Sliced band jitter that resolves or degrades.',
  ),
  EffectCatalogEntry(
    EffectSpecKind.parallax,
    group: 'Motion',
    blurb: 'A depth-scaled drift with the scene camera.',
  ),
  EffectCatalogEntry(
    EffectSpecKind.particles,
    group: 'Generative',
    blurb: 'A seeded particle field: sparkle, confetti, snow.',
  ),
  EffectCatalogEntry(
    EffectSpecKind.shader,
    group: 'Generative',
    blurb: 'Your own fragment shader over the element.',
  ),
];

/// The catalog filtered by [query]: case-insensitive, matching the kind
/// name or the blurb. An empty query is the whole catalog.
List<EffectCatalogEntry> searchEffectCatalog(String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return effectCatalog;
  return [
    for (final entry in effectCatalog)
      if (entry.kind.name.toLowerCase().contains(needle) ||
          entry.blurb.toLowerCase().contains(needle))
        entry,
  ];
}
