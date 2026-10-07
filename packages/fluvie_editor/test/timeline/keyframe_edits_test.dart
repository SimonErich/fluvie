import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

void main() {
  group('movedStopFrames', () {
    test('moves one stop and keeps the rest', () {
      expect(
        movedStopFrames(stopFrames: const [0, 15, 30], stop: 1, offset: 20, span: 30),
        [0, 20, 30],
      );
    });

    test('clamps between the neighboring stops', () {
      expect(
        movedStopFrames(stopFrames: const [0, 15, 30], stop: 1, offset: 30, span: 30),
        [0, 29, 30],
      );
      expect(
        movedStopFrames(stopFrames: const [0, 15, 30], stop: 1, offset: -4, span: 30),
        [0, 1, 30],
      );
    });

    test('the boundary stops clamp to the span itself', () {
      expect(
        movedStopFrames(stopFrames: const [5, 15, 30], stop: 0, offset: -9, span: 30),
        [0, 15, 30],
      );
      expect(
        movedStopFrames(stopFrames: const [10, 15, 30], stop: 0, offset: 0, span: 30),
        [0, 15, 30],
      );
      expect(
        movedStopFrames(stopFrames: const [0, 15, 20], stop: 2, offset: 99, span: 30),
        [0, 15, 30],
      );
    });

    test('returns null when the stop cannot move (or nothing changed)', () {
      // Neighbors one frame apart leave no room.
      expect(
        movedStopFrames(stopFrames: const [0, 1, 2], stop: 1, offset: 5, span: 2),
        isNull,
      );
      expect(
        movedStopFrames(stopFrames: const [0, 15, 30], stop: 1, offset: 15, span: 30),
        isNull,
      );
    });
  });

  group('insertedStop', () {
    const stops = <Object?>[
      {'opacity': 0.0, 'x': 0.5},
      {'opacity': 1.0},
    ];

    test('interpolates the fields the neighbors define', () {
      final inserted = insertedStop(stops: stops, stopFrames: const [0, 30], offset: 15)!;
      expect(inserted.stop, 1);
      expect(inserted.keyframe['opacity'], closeTo(0.5, 1e-9));
      // x is only on the left stop: the right side substitutes the natural 0.
      expect(inserted.keyframe['x'], closeTo(0.25, 1e-9));
      expect(inserted.positionFrames, [0, 15, 30]);
    });

    test('fields neither neighbor defines stay natural (absent)', () {
      final inserted = insertedStop(
        stops: const [{}, {}],
        stopFrames: const [0, 30],
        offset: 10,
      )!;
      expect(inserted.keyframe, isEmpty);
    });

    test('before the first stop the new stop holds the first values', () {
      final inserted = insertedStop(stops: stops, stopFrames: const [10, 30], offset: 4)!;
      expect(inserted.stop, 0);
      expect(inserted.keyframe['opacity'], 0.0);
      expect(inserted.keyframe['x'], 0.5);
      expect(inserted.positionFrames, [4, 10, 30]);
    });

    test('after the last stop the new stop holds the last values', () {
      final inserted = insertedStop(stops: stops, stopFrames: const [0, 20], offset: 26)!;
      expect(inserted.stop, 2);
      expect(inserted.keyframe['opacity'], 1.0);
      expect(inserted.positionFrames, [0, 20, 26]);
    });

    test('an offset already holding a stop inserts nothing', () {
      expect(insertedStop(stops: stops, stopFrames: const [0, 30], offset: 30), isNull);
      expect(insertedStop(stops: stops, stopFrames: const [0, 30], offset: 0), isNull);
    });
  });

  group('rescaledStopFrames', () {
    test('keeps the stops proportional over a new span', () {
      expect(rescaledStopFrames(const [0, 15, 30], from: 30, to: 60), [0, 30, 60]);
      expect(rescaledStopFrames(const [0, 20, 30], from: 30, to: 15), [0, 10, 15]);
    });

    test('stays strictly increasing when rounding collides', () {
      expect(rescaledStopFrames(const [0, 14, 15, 30], from: 30, to: 6), [0, 3, 4, 6]);
    });

    test('returns null when the span cannot hold the stops', () {
      expect(rescaledStopFrames(const [0, 10, 20, 30], from: 30, to: 2), isNull);
    });
  });
}
