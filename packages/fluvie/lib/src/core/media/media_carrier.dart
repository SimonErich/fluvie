import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/core/media/snapshot_source.dart';

/// A widget that declares media the collect pass must pre-resolve before the
/// frame loop: a loaded [MediaSource], a computed
/// [SnapshotSource], or neither.
///
/// `Image`, `Clip`, and `Background.image`/`.video` declare a [mediaSource];
/// `Mermaid`, `WebView` and `Html` declare a [snapshotSource]. Both let the
/// static collect walks read the declaration from a `core` contract without
/// importing the element layers (which would invert the layering law). A carrier
/// whose accessor is `null` declares nothing of that kind — the walk skips it.
///
/// It is a pure structural marker: it carries no IO and no resolution, only the
/// already-constructed sources the element was built with. [snapshotSource]
/// defaults to `null`, so a media-only carrier keeps compiling unchanged.
abstract interface class MediaCarrier {
  /// The media this widget loads, or `null` when it declares none.
  MediaSource? get mediaSource;

  /// The snapshot this widget rasterizes, or `null` when it declares none.
  SnapshotSource? get snapshotSource => null;
}
