import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';
import 'package:fluvie/src/rendering/no_media_resolver.dart';

import '../../rendering/fakes/fake_media_resolver.dart';

void main() {
  group('ImageResolverScope', () {
    testWidgets('of returns the provided resolver', (tester) async {
      final resolver = FakeMediaResolver(const {});
      late final Object found;
      await tester.pumpWidget(
        ImageResolverScope(
          resolver: resolver,
          child: Builder(
            builder: (context) {
              found = ImageResolverScope.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(found, same(resolver));
    });

    testWidgets('maybeOf is null without a scope above', (tester) async {
      late final Object? found;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            found = ImageResolverScope.maybeOf(context);
            return const SizedBox.shrink();
          },
        ),
      );
      expect(found, isNull);
    });

    testWidgets('of throws without a scope above', (tester) async {
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            ImageResolverScope.of(context);
            return const SizedBox.shrink();
          },
        ),
      );
      expect(tester.takeException(), isA<FlutterError>());
    });

    testWidgets('updateShouldNotify is true on a resolver identity change', (tester) async {
      final a = ImageResolverScope(
        resolver: FakeMediaResolver(const {}),
        child: const SizedBox.shrink(),
      );
      const b = ImageResolverScope(
        resolver: NoMediaResolver(),
        child: SizedBox.shrink(),
      );
      final same = ImageResolverScope(resolver: a.resolver, child: const SizedBox.shrink());

      expect(b.updateShouldNotify(a), isTrue);
      expect(same.updateShouldNotify(a), isFalse);
    });
  });
}
