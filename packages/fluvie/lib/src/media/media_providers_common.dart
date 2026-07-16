import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:fluvie/src/media/media_bytes_loader.dart';
import 'package:fluvie/src/media/net/media_http_client.dart';
import 'package:fluvie/src/media/net/network_allowlist.dart';
import 'package:fluvie/src/media/web_clip_decoder.dart';
import 'package:riverpod/riverpod.dart';

/// The asset bundle media assets are read from; defaults to `rootBundle` and
/// is overridable with a fake bundle in tests.
final assetBundleProvider = Provider<AssetBundle>((ref) => rootBundle);

/// The network safety gate consulted before any media fetch; defaults to a
/// host-open, https-only allowlist and is overridable to a strict set.
final networkAllowlistProvider = Provider<NetworkAllowlist>(
  (ref) => NetworkAllowlist.allowAny(),
);

/// The per-kind byte source the media resolver resolves over; web-safe (the
/// `file://` branch is behind a platform seam), so both platform resolvers
/// build over it.
final mediaBytesLoaderProvider = Provider<MediaBytesLoader>(
  (ref) => MediaBytesLoader(
    bundle: ref.watch(assetBundleProvider),
    httpClient: ref.watch(mediaHttpClientProvider),
    allowlist: ref.watch(networkAllowlistProvider),
  ),
);

/// The in-browser clip decoder (WebCodecs), or `null` for images-only web
/// rendering. The base package ships no decoder; `fluvie_web_encoder` overrides
/// this with its WebCodecs implementation so a `Clip` renders in the browser.
final webClipDecoderProvider = Provider<WebClipDecoder?>((ref) => null);

/// Whether clip frames stream through an on-disk store, decoding only the
/// bounded window each frame paints (the default, on the platforms that have a
/// store), or are all decoded up front.
///
/// Streaming is only safe when something drives `ClipFramePreparer`
/// .prepareClipFrames before each frame — which is the capture loop, and only
/// the capture loop. A live preview has no such loop (its ticker is synchronous
/// and cannot await a decode), so it turns this off and every planned frame is
/// decoded up front instead, bounded by [clipDecodeMaxEdgeProvider].
final clipFrameStreamingProvider = Provider<bool>((ref) => true);

/// The longest side a clip is decoded at, or `null` (the default) for the
/// source's own resolution.
///
/// A render leaves this null so the encoder gets every pixel the source has. A
/// live preview overrides it with a proxy bound, because the decoded frames are
/// held in memory (~8.3 MB per full-HD frame) while the app is running. It moves
/// resolution only: fps, frame count, and resampling are untouched.
final clipDecodeMaxEdgeProvider = Provider<int?>((ref) => null);
