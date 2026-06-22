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
  });
}
