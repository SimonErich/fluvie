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
