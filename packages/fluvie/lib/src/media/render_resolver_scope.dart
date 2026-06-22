import 'package:fluvie/src/core/contracts/disposable_resolver.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/media/media_resolver_provider.dart';
import 'package:fluvie/src/media/net/network_allowlist.dart';
import 'package:fluvie/src/media/web_clip_decoder.dart';
import 'package:riverpod/riverpod.dart';

/// A media resolver for one render plus the teardown that releases it.
typedef ResolverScope = ({MediaResolver resolver, Future<void> Function() dispose});

/// Resolves the [MediaResolver] a render uses and the matching teardown.
///
/// When [injected] is non-null it is used as-is and the caller keeps ownership:
/// `dispose` is a no-op (the renderer never disposes a resolver it does not own).
/// Otherwise a fresh resolver is built from `mediaResolverProvider` over an owned
/// `ProviderContainer` — with [networkAllowlist] applied when given (so network
/// image media works without a Riverpod override) and [clipDecoder] applied when
/// given (so an in-browser `Clip` renders through WebCodecs) — and `dispose`
/// releases that resolver's native resources (if it is a [DisposableResolver])
/// and the container.
ResolverScope resolverScope(
  MediaResolver? injected, {
  NetworkAllowlist? networkAllowlist,
  WebClipDecoder? clipDecoder,
}) {
  if (injected != null) {
    return (resolver: injected, dispose: () async {});
  }
  final container = ProviderContainer(
    overrides: [
      if (networkAllowlist != null) networkAllowlistProvider.overrideWithValue(networkAllowlist),
      if (clipDecoder != null) webClipDecoderProvider.overrideWithValue(clipDecoder),
    ],
  );
  final resolver = container.read(mediaResolverProvider);
  return (
    resolver: resolver,
    dispose: () async {
      if (resolver is DisposableResolver) (resolver as DisposableResolver).dispose();
      container.dispose();
    },
  );
}
