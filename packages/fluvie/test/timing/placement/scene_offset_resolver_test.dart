import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/transition.dart';
import 'package:fluvie/src/timing/placement/scene_offset_resolver.dart';

void main() {
  group('resolveSceneOffsets (D3/D4)', () {
    test('no transitions: starts are running sums and total is the plain sum (back-compat)', () {
      final offsets = resolveSceneOffsets(
        fps: 30,
        durations: [2.seconds, 3.seconds, 45.frames],
      );

      expect(offsets.startFrames, [0, 60, 150]);
      expect(offsets.durationFrames, [60, 90, 45]);
      expect(offsets.transitionFrames, [0, 0]);
      expect(offsets.overlaps, [false, false]);
      expect(offsets.totalFrames, 195);
    });

    test('an empty composition resolves to zero scenes and zero frames', () {
      final offsets = resolveSceneOffsets(fps: 30, durations: []);

      expect(offsets.startFrames, isEmpty);
      expect(offsets.durationFrames, isEmpty);
      expect(offsets.transitionFrames, isEmpty);
      expect(offsets.overlaps, isEmpty);
      expect(offsets.totalFrames, 0);
    });

    test('overlap crossFade shortens the total by F per boundary and shifts downstream starts', () {
      final offsets = resolveSceneOffsets(
        fps: 30,
        durations: [2.seconds, 3.seconds, 45.frames],
        transitions: [Transition.crossFade(0.5.seconds), Transition.crossFade(10.frames)],
      );

      expect(offsets.transitionFrames, [15, 10]);
      expect(offsets.overlaps, [true, true]);
      expect(offsets.startFrames, [0, 45, 125]);
      expect(offsets.totalFrames, 195 - 15 - 10);
    });

    test('non-overlap transitions leave starts and total unchanged (D3)', () {
      final offsets = resolveSceneOffsets(
        fps: 30,
        durations: [2.seconds, 3.seconds, 45.frames],
        transitions: [
          Transition.crossFade(0.5.seconds, overlap: false),
          Transition.crossFade(10.frames, overlap: false),
        ],
      );

      expect(offsets.transitionFrames, [15, 10]);
      expect(offsets.overlaps, [false, false]);
      expect(offsets.startFrames, [0, 60, 150]);
      expect(offsets.totalFrames, 195);
    });

    test('mixed overlap and non-overlap boundaries shift only at the overlapping ones', () {
      final offsets = resolveSceneOffsets(
        fps: 30,
        durations: [2.seconds, 3.seconds, 45.frames],
        transitions: [
          Transition.crossFade(15.frames),
          Transition.crossFade(10.frames, overlap: false),
        ],
      );

      expect(offsets.startFrames, [0, 45, 135]);
      expect(offsets.totalFrames, 180);
    });

    test('cut boundaries shift nothing: identical to no transitions at all (D5)', () {
      final plain = resolveSceneOffsets(fps: 30, durations: [2.seconds, 3.seconds]);
      final cuts = resolveSceneOffsets(
        fps: 30,
        durations: [2.seconds, 3.seconds],
        transitions: const [Transition.cut()],
      );

      expect(cuts.startFrames, plain.startFrames);
      expect(cuts.transitionFrames, [0]);
      expect(cuts.overlaps, [false]);
      expect(cuts.totalFrames, plain.totalFrames);
    });

    test('rounding pin: 0.5 seconds at 25 fps is 13 frames (round half away from zero)', () {
      final offsets = resolveSceneOffsets(
        fps: 25,
        durations: [2.seconds, 2.seconds],
        transitions: [Transition.crossFade(0.5.seconds)],
      );

      expect(offsets.transitionFrames, [13]);
      expect(offsets.startFrames, [0, 50 - 13]);
    });

    test('a duration rounding to zero frames degenerates to a cut, never an error (D3)', () {
      final offsets = resolveSceneOffsets(
        fps: 30,
        durations: [2.seconds, 2.seconds],
        transitions: [Transition.crossFade(0.001.seconds)],
      );

      expect(offsets.transitionFrames, [0]);
      expect(offsets.startFrames, [0, 60]);
      expect(offsets.totalFrames, 120);
    });

    test('a relative transition duration throws, naming both scenes (D3)', () {
      expect(
        () => resolveSceneOffsets(
          fps: 30,
          durations: [2.seconds, 2.seconds],
          transitions: [Transition.crossFade(0.1.relative)],
          sceneIds: const ['intro', 'outro'],
        ),
        throwsA(
          isA<FluvieTimingError>().having(
            (e) => e.message,
            'message',
            allOf(contains("'intro'"), contains("'outro'"), contains('relative')),
          ),
        ),
      );
    });

    test('a transitions list of the wrong length throws an ArgumentError (D5)', () {
      expect(
        () => resolveSceneOffsets(
          fps: 30,
          durations: [2.seconds, 2.seconds],
          transitions: [Transition.crossFade(10.frames), Transition.crossFade(10.frames)],
        ),
        throwsArgumentError,
      );
      expect(
        () => resolveSceneOffsets(
          fps: 30,
          durations: [2.seconds],
          transitions: [Transition.crossFade(10.frames)],
        ),
        throwsArgumentError,
      );
    });

    test('a transition longer than its incoming neighbor throws, naming the scene (D3)', () {
      expect(
        () => resolveSceneOffsets(
          fps: 30,
          durations: [60.frames, 30.frames],
          transitions: [Transition.crossFade(40.frames)],
          sceneIds: const ['a', 'b'],
        ),
        throwsA(
          isA<FluvieTimingError>().having((e) => e.message, 'message', contains("'b'")),
        ),
      );
    });

    test('a blend head plus a live tail exceeding a middle scene throws, naming it (D3)', () {
      expect(
        () => resolveSceneOffsets(
          fps: 30,
          durations: [60.frames, 30.frames, 60.frames],
          transitions: [Transition.crossFade(20.frames), Transition.crossFade(20.frames)],
          sceneIds: const ['a', 'middle', 'c'],
        ),
        throwsA(
          isA<FluvieTimingError>().having(
            (e) => e.message,
            'message',
            allOf(contains("'middle'"), contains('crossFade')),
          ),
        ),
      );
    });

    test('the same head plus tail fits when the tail boundary does not overlap (D3)', () {
      final offsets = resolveSceneOffsets(
        fps: 30,
        durations: [60.frames, 30.frames, 60.frames],
        transitions: [
          Transition.crossFade(20.frames),
          Transition.crossFade(20.frames, overlap: false),
        ],
      );

      expect(offsets.startFrames, [0, 40, 70]);
      expect(offsets.totalFrames, 130);
    });

    test('a relative scene duration still throws via the D27 boundary math', () {
      expect(
        () => resolveSceneOffsets(
          fps: 30,
          durations: [0.5.relative, 2.seconds],
          sceneIds: const ['loop', 'next'],
        ),
        throwsA(
          isA<FluvieTimingError>().having((e) => e.message, 'message', contains("'loop'")),
        ),
      );
    });

    test('sceneIds default to the scenes[i] convention in error messages', () {
      expect(
        () => resolveSceneOffsets(fps: 30, durations: [0.5.relative]),
        throwsA(
          isA<FluvieTimingError>().having(
            (e) => e.message,
            'message',
            contains("'scenes[0]'"),
          ),
        ),
      );
    });

    test('resolution is deterministic: two calls produce field-equal records', () {
      SceneOffsets run() => resolveSceneOffsets(
        fps: 30,
        durations: [2.seconds, 3.seconds, 45.frames],
        transitions: [
          Transition.crossFade(15.frames),
          Transition.wipe(10.frames, overlap: false),
        ],
      );

      final first = run();
      final second = run();
      expect(first.startFrames, second.startFrames);
      expect(first.durationFrames, second.durationFrames);
      expect(first.transitionFrames, second.transitionFrames);
      expect(first.overlaps, second.overlaps);
      expect(first.totalFrames, second.totalFrames);
    });

    test('the returned lists are unmodifiable views', () {
      final offsets = resolveSceneOffsets(fps: 30, durations: [2.seconds, 3.seconds]);

      expect(() => offsets.startFrames.add(0), throwsUnsupportedError);
      expect(() => offsets.durationFrames.add(0), throwsUnsupportedError);
      expect(() => offsets.transitionFrames.add(0), throwsUnsupportedError);
      expect(() => offsets.overlaps.add(false), throwsUnsupportedError);
    });
  });
}
