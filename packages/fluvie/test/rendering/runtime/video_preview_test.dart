import 'package:flutter/material.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

class _Audio implements PreviewAudioController {
  int activations = 0;
  final updates = <({Duration position, bool playing, double rate})>[];
  @override
  Future<void> activate() async => activations++;
  @override
  Future<void> synchronize({
    required Duration position,
    required bool playing,
    required double rate,
  }) async {
    updates.add((position: position, playing: playing, rate: rate));
  }

  @override
  Future<void> dispose() async {}
}

Video _video(String title) => Video(
  width: 100,
  height: 100,
  scenes: [
    Scene(duration: 90.frames, children: [Text(title)]),
  ],
);

void main() {
  testWidgets('playing a sought final picture retains its interval and audio reaches duration', (
    tester,
  ) async {
    final audio = _Audio();
    await tester.pumpWidget(
      MaterialApp(
        home: VideoPreview(video: _video('Final'), autoplay: false, audio: audio),
      ),
    );
    await tester.pumpAndSettle();
    final clock = tester.widget<LivePlayer>(find.byType(LivePlayer)).controller..seek(89);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Play'));
    await tester.pump();
    expect(clock.frame, 89);
    await tester.pump(const Duration(milliseconds: 40));
    expect(clock.isComplete, isTrue);
    expect(audio.updates.last.position, const Duration(seconds: 3));
    expect(audio.updates.last.playing, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('custom surfaces keep preparation, canvas and playback without Material', (
    tester,
  ) async {
    var ready = false;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 100,
          height: 100,
          child: VideoPreview(
            video: _video('Album'),
            autoplay: false,
            showControls: false,
            onReady: (_) => ready = true,
            surfaceBuilder: (context, canvas, prepared, failure) =>
                SizedBox(key: const Key('album-surface'), width: 100, height: 100, child: canvas),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(ready, isTrue);
    expect(find.byKey(const Key('album-surface')), findsOneWidget);
    expect(find.byType(Material), findsNothing);
    expect(find.text('Album'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('hot reload refreshes a builder while preserving position and a user pause', (
    tester,
  ) async {
    var title = 'First';
    var builds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: VideoPreview.builder(
          autoplay: false,
          builder: () {
            builds++;
            return _video(title);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester.widget<LivePlayer>(find.byType(LivePlayer)).controller.seek(45);
    await tester.pumpAndSettle();
    title = 'Reloaded';
    final reassembly = tester.binding.reassembleApplication();
    await tester.pumpAndSettle();
    await reassembly;
    final nextClock = tester.widget<LivePlayer>(find.byType(LivePlayer)).controller;
    expect(builds, 2);
    expect(find.text('Reloaded'), findsOneWidget);
    expect(nextClock.frame, 45);
    expect(nextClock.state, LivePlaybackState.paused);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Play activates platform audio in a gesture and synchronizes pause/scrub', (
    tester,
  ) async {
    final audio = _Audio();
    await tester.pumpWidget(
      MaterialApp(
        home: VideoPreview(video: _video('Sound'), autoplay: false, audio: audio),
      ),
    );
    await tester.pumpAndSettle();
    expect(audio.activations, 0);
    await tester.tap(find.byTooltip('Play'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(audio.activations, 1);
    expect(audio.updates.last.playing, isTrue);
    await tester.tap(find.byTooltip('Pause'));
    await tester.pumpAndSettle();
    expect(audio.updates.last.playing, isFalse);
    tester.widget<LivePlayer>(find.byType(LivePlayer)).controller.seek(30);
    await tester.pumpAndSettle();
    expect(audio.updates.last.position, const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('visual autoplay starts muted without activating browser audio', (tester) async {
    final audio = _Audio();
    await tester.pumpWidget(
      MaterialApp(
        home: VideoPreview(video: _video('Autoplay'), audio: audio),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    final clock = tester.widget<LivePlayer>(find.byType(LivePlayer)).controller;
    expect(clock.state, LivePlaybackState.playing);
    expect(audio.activations, 0);
    expect(audio.updates, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
}
