part of 'background.dart';

/// `Background.image`: a full-canvas still image.
///
/// Paint delegates to [ResolvedImage], the shared image-resolution widget the
/// `Image` element also uses: in capture it reads the pre-resolved `ui.Image`
/// from the enclosing `ImageResolverScope` and paints a synchronous `RawImage`;
/// a capture with no resolution is a typed failure naming the source; a live
/// preview falls back to Flutter's async asset path. The duplicated lookup that
/// once lived here is gone — there is one image-resolution code path.
final class _ImageBackdrop extends _BackgroundSpec {
  const _ImageBackdrop(this.source, {required this.fit});

  /// The bundle asset key, mapped to a [MediaSource.asset] for resolution.
  final String source;
  final BoxFit fit;

  MediaSource get _media => MediaSource.asset(source);

  @override
  MediaSource? get mediaSource => _media;

  @override
  Widget build(BuildContext context) => ResolvedImage(source: _media, fit: fit);
}

/// `Background.video`: a full-canvas video backdrop.
///
/// Paint delegates to [ClipPainter], the same clip path the `Clip` element
/// uses: the source is pre-resolved as a *clip* (probed and frame-extracted by
/// `preResolveClip`, not decoded as an image), and per composition frame the
/// painter resamples to a source frame and paints the cached `ui.Image`
/// synchronously. A capture with no resolution is a typed failure naming the
/// source; a live preview paints a placeholder. The backdrop fills the canvas
/// with [BoxFit.cover] and plays the whole source (no trim).
final class _VideoBackdrop extends _BackgroundSpec {
  const _VideoBackdrop(this.source);

  /// The bundle asset key, mapped to a [MediaSource.asset] for resolution.
  final String source;

  MediaSource get _media => MediaSource.asset(source);

  @override
  MediaSource? get mediaSource => _media;

  @override
  Widget build(BuildContext context) => ClipPainter(source: _media, fit: BoxFit.cover);
}
