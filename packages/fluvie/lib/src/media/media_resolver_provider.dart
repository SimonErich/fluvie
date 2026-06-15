import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/media/media_bytes_loader.dart';
import 'package:fluvie/src/media/media_repository.dart';
import 'package:fluvie/src/media/net/media_http_client.dart';
import 'package:fluvie/src/media/net/network_allowlist.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_frame_extraction_service.dart';
import 'package:fluvie/src/rendering/encoding/video_probe_service.dart';
import 'package:riverpod/riverpod.dart';

/// The asset bundle media assets are read from; defaults to `rootBundle` and
/// is overridable with a fake bundle in tests.
final assetBundleProvider = Provider<AssetBundle>((ref) => rootBundle);

/// The network safety gate consulted before any media fetch; defaults to a
/// host-open, https-only allowlist and is overridable to a strict set.
final networkAllowlistProvider = Provider<NetworkAllowlist>(
  (ref) => NetworkAllowlist.allowAny(),
);

/// The per-kind byte source the [mediaResolverProvider] resolves over.
final mediaBytesLoaderProvider = Provider<MediaBytesLoader>(
  (ref) => MediaBytesLoader(
    bundle: ref.watch(assetBundleProvider),
    httpClient: ref.watch(mediaHttpClientProvider),
    allowlist: ref.watch(networkAllowlistProvider),
  ),
);

/// The media resolver used by the render pipeline: a real [MediaRepository]
/// over the injected loader plus the clip probe/extraction services. The
/// `MediaResolver` and `FrameExtractionService` are the real implementations.
/// Overridable with a fake in tests; `NoMediaResolver` stays exported as the
/// deliberate media-less choice.
final mediaResolverProvider = Provider<MediaResolver>(
  (ref) => MediaRepository(
    loader: ref.watch(mediaBytesLoaderProvider),
    probeService: ref.watch(videoProbeServiceProvider),
    frameExtractor: ref.watch(frameExtractionServiceProvider),
  ),
);
