import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/rendering.dart';
import 'package:mocktail/mocktail.dart';

class _Player extends Mock implements PreviewAudioPlayer {}

void main() {
  setUpAll(() => registerFallbackValue(Duration.zero));
  late _Player player;
  late Duration position;
  late bool playing;
  late double gain;
  setUp(() {
    player = _Player();
    position = Duration.zero;
    playing = false;
    gain = 0;
    when(() => player.duration).thenReturn(const Duration(seconds: 30));
    when(() => player.position).thenAnswer((_) => position);
    when(() => player.playing).thenAnswer((_) => playing);
    when(() => player.rate).thenReturn(1);
    when(() => player.volume).thenAnswer((_) => gain);
    when(
      () => player.seek(any()),
    ).thenAnswer((i) async => position = i.positionalArguments.single as Duration);
    when(
      () => player.setVolume(any()),
    ).thenAnswer((i) async => gain = i.positionalArguments.single as double);
    when(() => player.setRate(any())).thenAnswer((_) async {});
    when(player.play).thenAnswer((_) async => playing = true);
    when(player.pause).thenAnswer((_) async => playing = false);
    when(player.dispose).thenAnswer((_) async {});
  });
  TimelinePreviewAudioController controller(ResolvedAudioTrack track) =>
      TimelinePreviewAudioController(
        mix: () => ResolvedAudioMix(tracks: [track]),
        createPlayer: (_) async => player,
      );
  test('unready media can be activated again after resolution succeeds', () async {
    var ready = false;
    final audio = TimelinePreviewAudioController(
      mix: () {
        if (!ready) throw StateError('not ready');
        return const ResolvedAudioMix(tracks: [ResolvedAudioTrack(source: 'clip')]);
      },
      createPlayer: (_) async => player,
    );
    await expectLater(audio.activate(), throwsStateError);
    ready = true;
    await audio.activate();
    await audio.synchronize(position: Duration.zero, playing: true, rate: 1);
    expect(playing, isTrue);
    await audio.dispose();
  });
  test('clip audio starts at its delayed trimmed source and stops at the trim end', () async {
    final audio = controller(
      const ResolvedAudioTrack(
        source: 'clip',
        delayMs: 2000,
        trimStartSeconds: 5,
        trimEndSeconds: 8,
        volume: .5,
      ),
    );
    await audio.activate();
    await audio.synchronize(position: const Duration(seconds: 1), playing: true, rate: 1);
    verifyNever(player.play);
    await audio.synchronize(position: const Duration(seconds: 3), playing: true, rate: 1);
    expect(position, const Duration(seconds: 6));
    expect(playing, true);
    expect(gain, .5);
    await audio.synchronize(position: const Duration(seconds: 5), playing: true, rate: 1);
    expect(playing, false);
    await audio.dispose();
    verify(player.dispose).called(1);
  });
  test('music repeats within its trim and follows gain automation and fade-out', () async {
    final audio = controller(
      const ResolvedAudioTrack(
        source: 'music',
        loop: true,
        trimStartSeconds: 0,
        trimEndSeconds: 4,
        volume: .5,
        volumeEnvelope: [AudioVolumePoint(0, 1), AudioVolumePoint(10, .5)],
        fadeOutSeconds: 2,
        fadeOutStartSeconds: 8,
      ),
    );
    await audio.activate();
    await audio.synchronize(position: const Duration(seconds: 6), playing: true, rate: 1);
    expect(position, const Duration(seconds: 2));
    expect(gain, closeTo(.35, 1e-6));
    await audio.synchronize(position: const Duration(seconds: 9), playing: true, rate: 1);
    expect(position, const Duration(seconds: 1));
    expect(gain, closeTo(.1375, 1e-6));
    await audio.dispose();
  });
  test('clock ticks coalesce while a platform seek is pending', () async {
    final first = Completer<void>();
    final sought = <Duration>[];
    when(() => player.seek(any())).thenAnswer((i) async {
      position = i.positionalArguments.single as Duration;
      sought.add(position);
      if (sought.length == 1) await first.future;
    });
    final audio = controller(const ResolvedAudioTrack(source: 'clip'));
    await audio.activate();
    final syncing = audio.synchronize(position: const Duration(seconds: 3), playing: true, rate: 1);
    unawaited(audio.synchronize(position: const Duration(seconds: 4), playing: true, rate: 1));
    unawaited(audio.synchronize(position: const Duration(seconds: 5), playing: true, rate: 1));
    first.complete();
    await syncing;
    expect(sought, [const Duration(seconds: 3), const Duration(seconds: 5)]);
    await audio.dispose();
  });
  test('disposing during preparation releases a player that arrives late', () async {
    final ready = Completer<PreviewAudioPlayer>();
    final audio = TimelinePreviewAudioController(
      mix: () => const ResolvedAudioMix(tracks: [ResolvedAudioTrack(source: 'clip')]),
      createPlayer: (_) => ready.future,
    );
    final preparing = audio.activate();
    final disposing = audio.dispose();
    ready.complete(player);
    await preparing;
    await disposing;
    verify(player.dispose).called(1);
    verifyNever(player.play);
  });
}
