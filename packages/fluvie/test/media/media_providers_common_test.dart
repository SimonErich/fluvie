import 'package:flutter/services.dart' show AssetBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/media/media_bytes_loader.dart';
import 'package:fluvie/src/media/media_providers_common.dart';
import 'package:fluvie/src/media/net/media_http_client.dart';
import 'package:fluvie/src/media/net/network_allowlist.dart';
import 'package:fluvie/src/media/web_clip_decoder.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class _MockAssetBundle extends Mock implements AssetBundle {}

class _MockMediaHttpClient extends Mock implements MediaHttpClient {}

class _MockWebClipDecoder extends Mock implements WebClipDecoder {}

void main() {
  group('media_providers_common', () {
    test('a fresh container resolves every provider to its real default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(assetBundleProvider), isA<AssetBundle>());
      expect(container.read(networkAllowlistProvider), isA<NetworkAllowlist>());
      expect(container.read(mediaBytesLoaderProvider), isA<MediaBytesLoader>());
      expect(container.read(webClipDecoderProvider), isNull);
    });

    test('every provider is overridable', () {
      final bundle = _MockAssetBundle();
      const allowlist = NetworkAllowlist(hosts: {});
      // MediaBytesLoader is a final class, so it cannot be mocked; a real one
      // built over a mock http client is the override value.
      final loader = MediaBytesLoader(
        httpClient: _MockMediaHttpClient(),
        allowlist: allowlist,
      );
      final decoder = _MockWebClipDecoder();

      final container = ProviderContainer(
        overrides: [
          assetBundleProvider.overrideWithValue(bundle),
          networkAllowlistProvider.overrideWithValue(allowlist),
          mediaBytesLoaderProvider.overrideWithValue(loader),
          webClipDecoderProvider.overrideWithValue(decoder),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(assetBundleProvider), same(bundle));
      expect(container.read(networkAllowlistProvider), same(allowlist));
      expect(container.read(mediaBytesLoaderProvider), same(loader));
      expect(container.read(webClipDecoderProvider), same(decoder));
    });

    test('the default loader is built from the sibling bundle and allowlist', () {
      final bundle = _MockAssetBundle();
      final container = ProviderContainer(
        overrides: [assetBundleProvider.overrideWithValue(bundle)],
      );
      addTearDown(container.dispose);

      // Reading the loader wires the overridden bundle in without throwing:
      // the default factory watches assetBundleProvider/networkAllowlistProvider.
      expect(container.read(mediaBytesLoaderProvider), isA<MediaBytesLoader>());
    });

    test('a container with every provider read disposes cleanly', () {
      final container = ProviderContainer()
        ..read(assetBundleProvider)
        ..read(networkAllowlistProvider)
        ..read(mediaBytesLoaderProvider)
        ..read(webClipDecoderProvider);

      expect(container.dispose, returnsNormally);
    });
  });
}
