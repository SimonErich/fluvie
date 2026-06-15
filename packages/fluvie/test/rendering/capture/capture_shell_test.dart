// Epic 14.5 (WI-21, D-CaptureShell): buildCaptureShell is the ONE capture path
// the example (offline fakes) and the CLI (real ffmpeg) share. It mounts the
// scope chain in this exact order and only mounts each conditional scope when it
// has something to carry:
//
//   RenderModeContext(capture)
//     > [SnapshotCaptureScope when snapshots]
//       > RenderControllerScope
//         > [ImageResolverScope when a resolver]
//           > RepaintBoundary(boundaryKey)
//             > [ReactiveScope when reactive tracks]
//               > [BeatGridScope when beat grids]
//                 > composition
//
// The shell bakes neither flutter_test nor ffmpeg in: it is a pure widget-tree
// builder, parameterized by the injected pre-pass results.

import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/runtime/reactive_scope.dart';
import 'package:fluvie/src/composition/runtime/reactive_collector.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/audio/band_table.dart';
import 'package:fluvie/src/core/audio_band.dart';
import 'package:fluvie/src/core/contracts/beat_grid.dart';
import 'package:fluvie/src/elements/snapshot/runtime/snapshot_capture_scope.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';
import 'package:fluvie/src/rendering/capture/beat_grid_scope.dart';
import 'package:fluvie/src/rendering/capture/capture_shell.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';

import '../../timing/fakes/fake_beat_grid.dart';
import '../fakes/fake_media_resolver.dart';

const _kLeaf = Key('composition-leaf');

BandTable _table() => BandTable({
  AudioBand.bass: Float64List.fromList(const [0, 1]),
});

/// A pre-resolved fake (the shell reads tables/grids synchronously, exactly as
/// it would after the real pre-pass completed before frame 0).
Future<FakeMediaResolver> _resolver({
  Map<AudioSource, BandTable> bandTables = const {},
  Map<AudioSource, BeatGrid> beatGrids = const {},
}) async {
  final resolver = FakeMediaResolver(const {}, bandTables: bandTables, beatGrids: beatGrids);
  await resolver.preResolveAll(const []);
  return resolver;
}

ReactiveTracks _reactiveTracks(AudioSource source) =>
    ReactiveTracks(byAnchor: const {}, defaultSource: source, allSources: {source});

void main() {
  group('buildCaptureShell — the scope chain (WI-21)', () {
    testWidgets('mounts the full chain in the correct order', (tester) async {
      const song = AudioSource.asset('audio/song.mp3');
      final resolver = await _resolver(
        bandTables: {song: _table()},
        beatGrids: {
          song: FakeBeatGrid(const [0]),
        },
      );
      final shell = buildCaptureShell(
        composition: const SizedBox(key: _kLeaf),
        boundaryKey: GlobalKey(),
        controller: RenderController(),
        resolver: resolver,
        snapshotScope: SnapshotCaptureScope(images: const {}),
        reactiveTracks: _reactiveTracks(song),
      );
      await tester.pumpWidget(shell.tree);

      // Every scope is present, and the depth order matches the contract.
      final modeDepth = _depthOf(tester, find.byType(RenderModeContext));
      final snapDepth = _depthOf(tester, find.byType(SnapshotCaptureScope));
      final ctrlDepth = _depthOf(tester, find.byType(RenderControllerScope));
      final imgDepth = _depthOf(tester, find.byType(ImageResolverScope));
      final boundaryDepth = _depthOf(tester, find.byType(RepaintBoundary));
      final reactiveDepth = _depthOf(tester, find.byType(ReactiveScope));
      final beatDepth = _depthOf(tester, find.byType(BeatGridScope));
      final leafDepth = _depthOf(tester, find.byKey(_kLeaf));

      final depths = [
        modeDepth,
        snapDepth,
        ctrlDepth,
        imgDepth,
        boundaryDepth,
        reactiveDepth,
        beatDepth,
        leafDepth,
      ];
      final sorted = [...depths]..sort();
      expect(depths, sorted, reason: 'the scope chain order does not match the contract');
      expect(RenderModeContext.isCapture(_contextAt(tester, find.byKey(_kLeaf))), isTrue);
    });

    testWidgets('a media-less composition mounts no ImageResolverScope', (tester) async {
      final shell = buildCaptureShell(
        composition: const SizedBox(key: _kLeaf),
        boundaryKey: GlobalKey(),
        controller: RenderController(),
      );
      await tester.pumpWidget(shell.tree);
      expect(find.byType(ImageResolverScope), findsNothing);
    });

    testWidgets('a snapshot-less composition mounts no SnapshotCaptureScope', (tester) async {
      final shell = buildCaptureShell(
        composition: const SizedBox(key: _kLeaf),
        boundaryKey: GlobalKey(),
        controller: RenderController(),
      );
      await tester.pumpWidget(shell.tree);
      expect(find.byType(SnapshotCaptureScope), findsNothing);
    });

    testWidgets('a reactive-less composition mounts no ReactiveScope', (tester) async {
      final shell = buildCaptureShell(
        composition: const SizedBox(key: _kLeaf),
        boundaryKey: GlobalKey(),
        controller: RenderController(),
      );
      await tester.pumpWidget(shell.tree);
      expect(find.byType(ReactiveScope), findsNothing);
    });

    testWidgets('a beat-grid-less composition mounts no BeatGridScope', (tester) async {
      const song = AudioSource.asset('audio/song.mp3');
      // The track has a band table (so the ReactiveScope mounts) but no beat
      // grid, so the BeatGridScope is skipped.
      final resolver = await _resolver(bandTables: {song: _table()});
      final shell = buildCaptureShell(
        composition: const SizedBox(key: _kLeaf),
        boundaryKey: GlobalKey(),
        controller: RenderController(),
        resolver: resolver,
        reactiveTracks: _reactiveTracks(song),
      );
      await tester.pumpWidget(shell.tree);
      expect(find.byType(ReactiveScope), findsOneWidget);
      expect(find.byType(BeatGridScope), findsNothing);
    });

    testWidgets('the minimal shell is just mode > controller > boundary > composition', (
      tester,
    ) async {
      final key = GlobalKey();
      final shell = buildCaptureShell(
        composition: const SizedBox(key: _kLeaf),
        boundaryKey: key,
        controller: RenderController(),
      );
      await tester.pumpWidget(shell.tree);
      expect(find.byType(RenderModeContext), findsOneWidget);
      expect(find.byType(RenderControllerScope), findsOneWidget);
      expect(find.byType(RepaintBoundary), findsOneWidget);
      expect(find.byKey(_kLeaf), findsOneWidget);
    });

    testWidgets('the resolver flows into the ImageResolverScope', (tester) async {
      const song = AudioSource.asset('audio/song.mp3');
      final resolver = await _resolver(bandTables: {song: _table()});
      final shell = buildCaptureShell(
        composition: const SizedBox(key: _kLeaf),
        boundaryKey: GlobalKey(),
        controller: RenderController(),
        resolver: resolver,
      );
      await tester.pumpWidget(shell.tree);
      final ctx = _contextAt(tester, find.byKey(_kLeaf));
      expect(ImageResolverScope.maybeOf(ctx), same(resolver));
    });

    testWidgets('the beat grids flow into the BeatGridScope', (tester) async {
      final drums = Anchor('drums');
      const song = AudioSource.asset('audio/song.mp3');
      const drumSrc = AudioSource.asset('audio/drums.wav');
      final defaultGrid = FakeBeatGrid(const [0]);
      final drumGrid = FakeBeatGrid(const [5]);
      final resolver = await _resolver(
        bandTables: {song: _table(), drumSrc: _table()},
        beatGrids: {song: defaultGrid, drumSrc: drumGrid},
      );
      final shell = buildCaptureShell(
        composition: const SizedBox(key: _kLeaf),
        boundaryKey: GlobalKey(),
        controller: RenderController(),
        resolver: resolver,
        reactiveTracks: ReactiveTracks(
          byAnchor: {drums: drumSrc},
          defaultSource: song,
          allSources: {song, drumSrc},
        ),
      );
      await tester.pumpWidget(shell.tree);
      final scope = BeatGridScope.maybeOf(_contextAt(tester, find.byKey(_kLeaf)))!;
      expect(scope.defaultBeatGrid, same(defaultGrid));
      expect(scope.trackBeatGrids[drums], same(drumGrid));
    });

    testWidgets('rebuilding the shell twice yields an identical chain', (tester) async {
      const song = AudioSource.asset('audio/song.mp3');
      Future<CaptureShell> shell() async {
        final resolver = await _resolver(
          bandTables: {song: _table()},
          beatGrids: {
            song: FakeBeatGrid(const [0]),
          },
        );
        return buildCaptureShell(
          composition: const SizedBox(key: _kLeaf),
          boundaryKey: GlobalKey(),
          controller: RenderController(),
          resolver: resolver,
          snapshotScope: SnapshotCaptureScope(images: const {}),
          reactiveTracks: _reactiveTracks(song),
        );
      }

      await tester.pumpWidget((await shell()).tree);
      final firstTypes = _chainTypes(tester);
      await tester.pumpWidget((await shell()).tree);
      final secondTypes = _chainTypes(tester);
      expect(firstTypes, secondTypes);
    });

    testWidgets('returns the mounted snapshot scope (a fresh cursor instance)', (tester) async {
      final prePass = SnapshotCaptureScope(images: const {});
      final shell = buildCaptureShell(
        composition: const SizedBox(key: _kLeaf),
        boundaryKey: GlobalKey(),
        controller: RenderController(),
        snapshotScope: prePass,
      );
      // The mounted scope shares the images but is a distinct instance, so the
      // host resets the mounted cursor, not the pre-pass result's.
      expect(shell.mountedSnapshotScope, isNotNull);
      expect(identical(shell.mountedSnapshotScope, prePass), isFalse);
      expect(shell.mountedSnapshotScope!.images, same(prePass.images));
    });

    testWidgets('mountedSnapshotScope is null for a snapshot-less composition', (tester) async {
      final shell = buildCaptureShell(
        composition: const SizedBox(key: _kLeaf),
        boundaryKey: GlobalKey(),
        controller: RenderController(),
      );
      expect(shell.mountedSnapshotScope, isNull);
    });
  });
}

/// The element depth of the first match — a larger number is deeper.
int _depthOf(WidgetTester tester, Finder finder) {
  var depth = 0;
  tester.element(finder.first).visitAncestorElements((_) {
    depth++;
    return true;
  });
  return depth;
}

BuildContext _contextAt(WidgetTester tester, Finder finder) => tester.element(finder.first);

List<String> _chainTypes(WidgetTester tester) => [
  for (final type in <Type>[
    RenderModeContext,
    SnapshotCaptureScope,
    RenderControllerScope,
    ImageResolverScope,
    RepaintBoundary,
    ReactiveScope,
    BeatGridScope,
  ])
    if (tester.any(find.byType(type))) '$type',
];
