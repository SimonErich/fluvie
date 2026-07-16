import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/contracts/disposable_resolver.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/media/media_repository.dart';
import 'package:fluvie/src/media/net/network_allowlist.dart';
import 'package:fluvie/src/media/render_resolver_scope.dart';
import 'package:fluvie/src/media/web_clip_decoder.dart';

/// A resolver that records whether the pipeline disposed it.
class _TrackingResolver implements MediaResolver, DisposableResolver {
  bool disposed = false;

  @override
  void dispose() => disposed = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// An unused clip decoder, just to exercise the override wiring.
class _NoopClipDecoder implements WebClipDecoder {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('resolverScope', () {
    test('uses an injected resolver as-is and never disposes it', () async {
      final injected = _TrackingResolver();
      final scope = resolverScope(injected);

      expect(scope.resolver, same(injected));
      await scope.dispose();

      expect(injected.disposed, isFalse, reason: 'the caller owns an injected resolver');
    });

    test('builds an owned resolver and disposes it on teardown', () async {
      final scope = resolverScope(null);

      expect(scope.resolver, isA<MediaResolver>());
      expect(scope.resolver, isA<DisposableResolver>());
      await expectLater(scope.dispose(), completes);
    });

    test('applies a network allowlist override to the owned container', () async {
      final scope = resolverScope(
        null,
        networkAllowlist: const NetworkAllowlist(hosts: {'cdn.example'}),
      );

      expect(scope.resolver, isA<MediaRepository>());
      await expectLater(scope.dispose(), completes);
    });

    test('applies a clip decoder override to the owned container', () async {
      final scope = resolverScope(null, clipDecoder: _NoopClipDecoder());

      expect(scope.resolver, isA<MediaResolver>());
      await expectLater(scope.dispose(), completes);
    });

    test('applies a clip decode bound to the owned resolver', () async {
      final scope = resolverScope(null, clipDecodeMaxEdge: 720);

      expect((scope.resolver as MediaRepository).maxClipDecodeEdge, 720);
      await expectLater(scope.dispose(), completes);
    });

    test(
      'leaves the clip decode bound null by default, so a render stays full resolution',
      () async {
        final scope = resolverScope(null);

        expect((scope.resolver as MediaRepository).maxClipDecodeEdge, isNull);
        await expectLater(scope.dispose(), completes);
      },
    );

    test('streams clip frames through a store by default, for the capture loop', () async {
      final scope = resolverScope(null);

      expect((scope.resolver as MediaRepository).clipFrameStore, isNotNull);
      await expectLater(scope.dispose(), completes);
    });

    test('streamClipFrames: false drops the store, so every frame decodes up front', () async {
      // The streaming window is only ever filled by the capture loop's
      // prepareClipFrames. A caller with no loop (a live preview) must decode
      // all, or paint's synchronous lookup misses on every frame.
      final scope = resolverScope(null, streamClipFrames: false);

      expect((scope.resolver as MediaRepository).clipFrameStore, isNull);
      await expectLater(scope.dispose(), completes);
    });
  });
}
