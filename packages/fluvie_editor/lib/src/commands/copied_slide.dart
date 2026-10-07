import 'package:meta/meta.dart' show immutable;

/// One slide as the clipboard carries it: the spec scene JSON plus the
/// slide's editor-block metadata (guides and friends).
///
/// The scene keeps its element ids in transit; paste re-mints every one on
/// the way in, so the payload is document-independent. The section marker
/// never travels — a copied slide is a slide, not a section boundary.
@immutable
final class CopiedSlide {
  /// Wraps the copied [scene] and its editor [meta].
  const CopiedSlide({required this.scene, this.meta = const {}});

  /// The scene JSON, element ids included.
  final Map<String, Object?> scene;

  /// The slide's editor-block metadata as copied.
  final Map<String, Object?> meta;

  /// The JSON form the envelope embeds.
  Map<String, Object?> toJson() => {'scene': scene, if (meta.isNotEmpty) 'meta': meta};

  /// Parses one envelope entry back into a copied slide, or null for
  /// anything that does not carry a scene.
  static CopiedSlide? tryParse(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final scene = json['scene'];
    if (scene is! Map<String, Object?>) return null;
    final meta = json['meta'];
    return CopiedSlide(scene: scene, meta: meta is Map<String, Object?> ? meta : const {});
  }
}
