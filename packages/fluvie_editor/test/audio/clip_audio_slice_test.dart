import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_editor/src/video_mode/clip_audio_slice.dart';

void main() {
  test('clip audio cut preserves every frame of curved volume and overlapping fades', () {
    const element = {
      'fadeIn': '0.8s',
      'fadeOut': '1.4s',
      'automation': {
        'volume': {
          'values': [0.2, 1.0, 0.1],
          'positions': ['0r', '0.45r', '1r'],
          'easings': ['inOut', 'bounce'],
        },
      },
    };
    const fps = 30;
    const duration = 90;
    const cut = 47;
    final original = decodeAudioAutomation(element['automation']).resolve(
      fps: fps,
      windowFrames: duration,
    );
    final slices = splitClipAudio(
      element: element,
      cutFrame: cut,
      windowFrames: duration,
      fps: fps,
    );
    final head = decodeAudioAutomation(slices.head['automation']).resolve(
      fps: fps,
      windowFrames: cut,
    );
    final tail = decodeAudioAutomation(slices.tail['automation']).resolve(
      fps: fps,
      windowFrames: duration - cut,
    );
    for (var frame = 0; frame <= duration; frame++) {
      final expected =
          audioVolumeAt(original, frame / fps) *
          (frame / 24).clamp(0.0, 1.0) *
          ((duration - frame) / 42).clamp(0.0, 1.0);
      final actual = frame <= cut
          ? audioVolumeAt(head, frame / fps)
          : audioVolumeAt(tail, (frame - cut) / fps);
      expect(actual, closeTo(expected, 1e-12), reason: 'output frame $frame');
    }
    expect(slices.head.containsKey('fadeIn'), isTrue);
    expect(slices.head['fadeIn'], isNull);
    expect(slices.tail['fadeOut'], isNull);
  });

  test('ordinary linear envelope remains exact between frames after clip cut', () {
    const element = {
      'automation': {
        'volume': {
          'values': [0.1, 1.0, 0.2],
          'positions': ['0f', '17f', '60f'],
        },
      },
    };
    final original = decodeAudioAutomation(
      element['automation'],
    ).resolve(fps: 30, windowFrames: 60);
    final slices = splitClipAudio(element: element, cutFrame: 29, windowFrames: 60, fps: 30);
    final tail = decodeAudioAutomation(
      slices.tail['automation'],
    ).resolve(fps: 30, windowFrames: 31);
    for (var frame = 29.0; frame <= 60; frame += 0.125) {
      expect(
        audioVolumeAt(tail, (frame - 29) / 30),
        closeTo(audioVolumeAt(original, frame / 30), 1e-12),
      );
    }
  });

  test('fade longer than clip retains its authored ramp slope through a cut', () {
    final slices = splitClipAudio(
      element: const {'fadeOut': '4s'},
      cutFrame: 30,
      windowFrames: 60,
      fps: 30,
    );
    final head = decodeAudioAutomation(
      slices.head['automation'],
    ).resolve(fps: 30, windowFrames: 30);
    final tail = decodeAudioAutomation(
      slices.tail['automation'],
    ).resolve(fps: 30, windowFrames: 30);
    expect(audioVolumeAt(head, 0), 1);
    expect(audioVolumeAt(head, 1), 0.75);
    expect(audioVolumeAt(tail, 0), 0.75);
    expect(audioVolumeAt(tail, 1), 0.5);
  });

  test('absent clip volume envelope preserves default serialization', () {
    final result = splitClipAudio(element: const {}, cutFrame: 15, windowFrames: 30, fps: 30);
    expect(result.head, isEmpty);
    expect(result.tail, isEmpty);
  });
}
