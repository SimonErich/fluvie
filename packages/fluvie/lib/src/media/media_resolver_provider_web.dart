import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/media/media_providers_common.dart';
import 'package:fluvie/src/media/web_image_media_resolver.dart';
import 'package:riverpod/riverpod.dart';

export 'package:fluvie/src/media/media_providers_common.dart';

/// The media resolver used by the in-browser render pipeline: a
/// [WebImageMediaResolver] over the injected loader, plus the
/// [webClipDecoderProvider] (null in the base package, the WebCodecs decoder
/// when `fluvie_web_encoder` overrides it). Audio, snapshots, and captions are
/// not available on web yet and fail with a clear typed error. Keeping this off
/// the `dart:io`-backed `MediaRepository` is what lets a web build reference
/// `mediaResolverProvider` without pulling `dart:io`.
final mediaResolverProvider = Provider<MediaResolver>(
  (ref) => WebImageMediaResolver(
    loader: ref.watch(mediaBytesLoaderProvider),
    clipDecoder: ref.watch(webClipDecoderProvider),
    maxClipDecodeEdge: ref.watch(clipDecodeMaxEdgeProvider),
  ),
);
