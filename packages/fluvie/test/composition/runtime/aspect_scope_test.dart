// Epic 14.2 (WI-6, D-Aspect / D-AspectScope): AspectScope carries the active
// Aspect down the tree, and the non-throwing AspectScope.of(BuildContext) reads
// the nearest scope, defaulting to Aspect.fallback (reels) with none. The
// BuildContext lookup lives here (the composition layer), not on the pure core
// Aspect enum.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/runtime/aspect_scope.dart';
import 'package:fluvie/src/core/aspect.dart';

void main() {
  group('AspectScope.of', () {
    testWidgets('reads the nearest AspectScope', (tester) async {
      late Aspect seen;
      await tester.pumpWidget(
        AspectScope(
          aspect: Aspect.square,
          child: Builder(
            builder: (context) {
              seen = AspectScope.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(seen, Aspect.square);
    });

    testWidgets('defaults to reels with no scope above', (tester) async {
      late Aspect seen;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            seen = AspectScope.of(context);
            return const SizedBox.shrink();
          },
        ),
      );
      expect(seen, Aspect.reels);
    });

    testWidgets('the innermost scope wins when nested', (tester) async {
      late Aspect seen;
      await tester.pumpWidget(
        AspectScope(
          aspect: Aspect.reels,
          child: AspectScope(
            aspect: Aspect.landscape,
            child: Builder(
              builder: (context) {
                seen = AspectScope.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(seen, Aspect.landscape);
    });

    testWidgets('maybeOf returns null with no scope and the value with one', (tester) async {
      late Aspect? bare;
      late Aspect? scoped;
      await tester.pumpWidget(
        Builder(
          builder: (outer) {
            bare = AspectScope.maybeOf(outer);
            return AspectScope(
              aspect: Aspect.portrait45,
              child: Builder(
                builder: (inner) {
                  scoped = AspectScope.maybeOf(inner);
                  return const SizedBox.shrink();
                },
              ),
            );
          },
        ),
      );
      expect(bare, isNull);
      expect(scoped, Aspect.portrait45);
    });

    testWidgets('updateShouldNotify fires only when the aspect changes', (tester) async {
      const a = AspectScope(aspect: Aspect.reels, child: SizedBox.shrink());
      const b = AspectScope(aspect: Aspect.square, child: SizedBox.shrink());
      expect(a.updateShouldNotify(b), isTrue);
      expect(
        a.updateShouldNotify(
          const AspectScope(aspect: Aspect.reels, child: SizedBox.shrink()),
        ),
        isFalse,
      );
    });
  });
}
