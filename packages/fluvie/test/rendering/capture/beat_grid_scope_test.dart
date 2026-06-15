import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/contracts/beat_grid.dart';
import 'package:fluvie/src/rendering/capture/beat_grid_scope.dart';

import '../../timing/fakes/fake_beat_grid.dart';

void main() {
  group('BeatGridScope', () {
    testWidgets('maybeOf returns the nearest scope', (tester) async {
      final grid = FakeBeatGrid(const [10, 20]);
      late BeatGridScope? seen;
      await tester.pumpWidget(
        BeatGridScope(
          defaultBeatGrid: grid,
          trackBeatGrids: const {},
          child: Builder(
            builder: (context) {
              seen = BeatGridScope.maybeOf(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen, isNotNull);
      expect(seen!.defaultBeatGrid, same(grid));
    });

    testWidgets('maybeOf returns null with no scope above', (tester) async {
      late BeatGridScope? seen;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            seen = BeatGridScope.maybeOf(context);
            return const SizedBox();
          },
        ),
      );
      expect(seen, isNull);
    });

    testWidgets('carries per-track grids keyed by anchor identity', (tester) async {
      final drums = Anchor('drums');
      final drumGrid = FakeBeatGrid(const [5]);
      late BeatGridScope? seen;
      await tester.pumpWidget(
        BeatGridScope(
          defaultBeatGrid: null,
          trackBeatGrids: {drums: drumGrid},
          child: Builder(
            builder: (context) {
              seen = BeatGridScope.maybeOf(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen!.trackBeatGrids[drums], same(drumGrid));
      expect(seen!.defaultBeatGrid, isNull);
    });

    test('isEmpty is true when there is no grid at all', () {
      const scope = BeatGridScope(
        defaultBeatGrid: null,
        trackBeatGrids: <Anchor, BeatGrid>{},
        child: SizedBox(),
      );
      expect(scope.isEmpty, isTrue);
    });

    test('the const constructor is usable for an empty scope', () {
      // The grid-less scope is a compile-time constant — the shell can skip
      // mounting it entirely, but a const empty form keeps the type usable.
      expect(
        const BeatGridScope(
          defaultBeatGrid: null,
          trackBeatGrids: <Anchor, BeatGrid>{},
          child: SizedBox(),
        ).isEmpty,
        isTrue,
      );
    });

    test('isEmpty is false with a default grid', () {
      final scope = BeatGridScope(
        defaultBeatGrid: FakeBeatGrid(const [0]),
        trackBeatGrids: const {},
        child: const SizedBox(),
      );
      expect(scope.isEmpty, isFalse);
    });

    test('isEmpty is false with only a track grid', () {
      final scope = BeatGridScope(
        defaultBeatGrid: null,
        trackBeatGrids: {
          Anchor('a'): FakeBeatGrid(const [0]),
        },
        child: const SizedBox(),
      );
      expect(scope.isEmpty, isFalse);
    });

    testWidgets('updateShouldNotify fires when the default grid changes', (tester) async {
      final a = BeatGridScope(
        defaultBeatGrid: FakeBeatGrid(const [0]),
        trackBeatGrids: const {},
        child: const SizedBox(),
      );
      final b = BeatGridScope(
        defaultBeatGrid: FakeBeatGrid(const [1]),
        trackBeatGrids: const {},
        child: const SizedBox(),
      );
      expect(b.updateShouldNotify(a), isTrue);
    });

    testWidgets('updateShouldNotify is false for the same grids', (tester) async {
      final grid = FakeBeatGrid(const [0]);
      final a = BeatGridScope(
        defaultBeatGrid: grid,
        trackBeatGrids: const {},
        child: const SizedBox(),
      );
      final b = BeatGridScope(
        defaultBeatGrid: grid,
        trackBeatGrids: const {},
        child: const SizedBox(),
      );
      expect(b.updateShouldNotify(a), isFalse);
    });
  });
}
