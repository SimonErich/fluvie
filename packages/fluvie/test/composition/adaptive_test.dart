// Epic 14.2 (WI-7, D-Adaptive): Adaptive picks the builder matching the active
// Aspect (read via AspectScope.of) and calls it; a null branch for the active aspect
// throws ArgumentError at build naming the aspect (a render asked for an
// unhandled aspect — fail loud, not blank). The branches are content-only — no
// transforms or timing — so layout differs across aspects while timing stays
// identical.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/adaptive.dart';
import 'package:fluvie/src/composition/runtime/aspect_scope.dart';
import 'package:fluvie/src/core/aspect.dart';

const _reels = Key('reels-branch');
const _square = Key('square-branch');
const _landscape = Key('landscape-branch');
const _portrait45 = Key('portrait45-branch');

Widget _allBranches() => Adaptive(
  reels: () => const SizedBox(key: _reels),
  square: () => const SizedBox(key: _square),
  landscape: () => const SizedBox(key: _landscape),
  portrait45: () => const SizedBox(key: _portrait45),
);

Widget _under(Aspect aspect, Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: AspectScope(aspect: aspect, child: child),
);

void main() {
  group('Adaptive branch selection', () {
    testWidgets('builds the reels branch under AspectScope(reels)', (tester) async {
      await tester.pumpWidget(_under(Aspect.reels, _allBranches()));
      expect(find.byKey(_reels), findsOneWidget);
      expect(find.byKey(_square), findsNothing);
      expect(find.byKey(_landscape), findsNothing);
      expect(find.byKey(_portrait45), findsNothing);
    });

    testWidgets('builds the square branch under AspectScope(square)', (tester) async {
      await tester.pumpWidget(_under(Aspect.square, _allBranches()));
      expect(find.byKey(_square), findsOneWidget);
      expect(find.byKey(_reels), findsNothing);
    });

    testWidgets('builds the landscape branch under AspectScope(landscape)', (tester) async {
      await tester.pumpWidget(_under(Aspect.landscape, _allBranches()));
      expect(find.byKey(_landscape), findsOneWidget);
      expect(find.byKey(_reels), findsNothing);
    });

    testWidgets('builds the portrait45 branch under AspectScope(portrait45)', (tester) async {
      await tester.pumpWidget(_under(Aspect.portrait45, _allBranches()));
      expect(find.byKey(_portrait45), findsOneWidget);
      expect(find.byKey(_reels), findsNothing);
    });

    testWidgets('falls back to reels with no scope', (tester) async {
      await tester.pumpWidget(
        Directionality(textDirection: TextDirection.ltr, child: _allBranches()),
      );
      expect(find.byKey(_reels), findsOneWidget);
    });

    testWidgets('a missing branch for the active aspect throws ArgumentError naming it', (
      tester,
    ) async {
      await tester.pumpWidget(
        _under(
          Aspect.landscape,
          Adaptive(reels: () => const SizedBox(key: _reels)),
        ),
      );
      final error = tester.takeException();
      expect(error, isArgumentError);
      expect((error as ArgumentError).message, contains('landscape'));
      expect(error.message, contains('Adaptive'));
    });

    testWidgets('an element deep in a branch reads the same aspect via AspectScope.of', (
      tester,
    ) async {
      late Aspect deep;
      await tester.pumpWidget(
        _under(
          Aspect.square,
          Adaptive(
            square: () => Builder(
              builder: (context) {
                deep = AspectScope.of(context);
                return const SizedBox.shrink();
              },
            ),
            reels: () => const SizedBox.shrink(),
          ),
        ),
      );
      expect(deep, Aspect.square);
    });

    testWidgets('only the active branch builder runs (the others are not called)', (tester) async {
      var squareCalls = 0;
      var reelsCalls = 0;
      await tester.pumpWidget(
        _under(
          Aspect.square,
          Adaptive(
            square: () {
              squareCalls++;
              return const SizedBox.shrink();
            },
            reels: () {
              reelsCalls++;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(squareCalls, 1);
      expect(reelsCalls, 0);
    });
  });
}
