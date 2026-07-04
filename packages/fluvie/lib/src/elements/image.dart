import 'dart:typed_data';

import 'package:flutter/widgets.dart' show BoxFit, BuildContext, StatelessWidget, Widget;
import 'package:fluvie/src/composition/frame.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/media/media_carrier.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/core/media/snapshot_source.dart';
import 'package:fluvie/src/elements/runtime/element_shared.dart';
import 'package:fluvie/src/media/runtime/resolved_image.dart';

/// A still image — Fluvie's own widget under Flutter's familiar `Image` name
/// (the barrel hides Flutter's).
///
/// A renderer must pre-resolve every source *before* capture so frames are
/// deterministic (no "pops in when it loads"): Fluvie pre-fetches, decodes, and
/// caches each source by content hash in the pre-resolve pass, then paints it
/// synchronously from the enclosing `ImageResolverScope`. A capture with no
/// pre-resolution throws a `FluvieRenderException` naming the source; a live
/// preview falls back to Flutter's async image path, where determinism does not
/// bind.
///
/// ```dart
/// Image.network('https://…/photo.jpg', fit: BoxFit.cover)
/// Image.asset('me.png', frame: Frame.polaroid(caption: 'Summer'))
/// Image.network('…').animate([Animation.slideFadeIn(), Animation.kenBurns(zoom: 1.2)]);
/// ```
///
/// [source] exposes the declared [MediaSource] for the collect pass
/// (`collectMediaSources`). An optional [frame] wraps the image in a decorative
/// `Frame`; an optional [shared] anchor wraps the result in a `SharedElement`
/// for a hero morph across a scene boundary. Transforms and effects come
/// through `.animate()` only, like every element.
final class Image extends StatelessWidget implements MediaCarrier {
  /// A remote image at [url] (a `Uri` or a `String`); only allowlisted hosts
  /// and schemes are fetched in capture.
  Image.network(Object url, {this.fit, this.frame, this.shared, super.key})
    : source = MediaSource.network(url is Uri ? url : Uri.parse(url as String));

  /// A bundled image addressed by its asset key [name]
  /// (for example `fixtures/swatch.png`).
  Image.asset(String name, {this.fit, this.frame, this.shared, super.key})
    : source = MediaSource.asset(name);

  /// An image file on disk at [path].
  Image.file(String path, {this.fit, this.frame, this.shared, super.key})
    : source = MediaSource.file(path);

  /// An image already in memory as raw encoded [bytes], optionally named by
  /// [debugLabel] for errors.
  Image.memory(Uint8List bytes, {String? debugLabel, this.fit, this.frame, this.shared, super.key})
    : source = MediaSource.memory(bytes, debugLabel: debugLabel);

  /// The declared media this image paints — the key the collect pass gathers
  /// and the resolver pre-resolves.
  final MediaSource source;

  /// This image's [source], exposed through the [MediaCarrier] contract so the
  /// collect pass reads it without importing the elements layer.
  @override
  MediaSource? get mediaSource => source;

  /// An `Image` declares no snapshot — it is a loaded media, not a computed one.
  @override
  SnapshotSource? get snapshotSource => null;

  /// How the image scales into its box, or `null` for Flutter's default.
  final BoxFit? fit;

  /// An optional decorative wrapper (`Frame.card`, `Frame.polaroid`, …), or
  /// `null` for a bare image.
  final Frame? frame;

  /// An optional hero anchor: when non-null the image morphs across the
  /// boundary it shares with the same anchor in the adjacent scene. `null`
  /// mounts no `SharedElement`.
  final Anchor? shared;

  @override
  Widget build(BuildContext context) {
    final Widget painted = ResolvedImage(source: source, fit: fit);
    final framed = frame == null ? painted : _reframe(frame!, painted);
    return wrapShared(shared, framed);
  }

  /// Rebuilds [frame] around [child]: a `Frame` declares its style at
  /// construction and carries its own child, so wrapping the image means
  /// re-issuing the same style with [child].
  static Frame _reframe(Frame frame, Widget child) => frame.withChild(child);
}
