import 'dart:typed_data';

import 'package:fluvie_media/fluvie_media.dart';
import 'package:test/test.dart';

void main() {
  test('invalid frame ordinals, dimensions and incomplete pixels cannot enter a frame cache', () {
    for (final value in [
      (index: -1, width: 1, height: 1, bytes: 4),
      (index: 0, width: 0, height: 1, bytes: 0),
      (index: 0, width: 1, height: 0, bytes: 0),
      (index: 0, width: 1, height: 1, bytes: 3),
    ]) {
      expect(
        () => MediaFrame(
          frameIndex: value.index,
          width: value.width,
          height: value.height,
          rgba: Uint8List(value.bytes),
        ),
        throwsArgumentError,
      );
    }
  });

  test('declared frame count provides duration when a container omits it', () {
    final info = MediaSourceInfo.fromReport(const {
      'streams': [
        {
          'codec_type': 'video',
          'width': 20,
          'height': 10,
          'avg_frame_rate': '5/1',
          'nb_frames': '10',
        },
      ],
    });
    expect(info.durationSeconds, 2);
    expect(info.frameCountIsEstimated, isFalse);
  });

  test('timeline JSON rejects malformed types and invalid clocks consistently', () {
    for (final json in <Map<String, Object?>>[
      {'schemaVersion': 1, 'fps': '30', 'frameCount': 4},
      {'schemaVersion': 1, 'fps': 30, 'frameCount': 1.5},
      {'schemaVersion': 1, 'fps': 0, 'frameCount': 4},
      {
        'schemaVersion': 1,
        'presentationTimesUs': [0, '1'],
        'durationUs': 2,
      },
      {
        'schemaVersion': 1,
        'presentationTimesUs': [0, 1],
        'durationUs': '2',
      },
      {'schemaVersion': 1, 'presentationTimesUs': [], 'durationUs': 2},
      {
        'schemaVersion': 1,
        'presentationTimesUs': [2, 1],
        'durationUs': 3,
      },
      {
        'schemaVersion': 1,
        'presentationTimesUs': [0, 1],
        'durationUs': 1,
      },
    ]) {
      expect(() => MediaTimeline.fromJson(json), throwsFormatException, reason: '$json');
    }
    expect(() => MediaTimeline.fromTimestamps([10]), throwsArgumentError);
  });

  test('duplicate first timestamps select the final picture at source zero', () {
    final timeline = MediaTimeline.fromTimestamps([100, 100, 200], endTimeUs: 300);
    expect(timeline.frameAt(0), 1);
    expect(timeline.interpolationAt(-1), (index: 0, nextIndex: 0, fraction: 0.0));
    expect(MediaTimeline.constant(fps: 2, frameCount: 4).frameAt(0), 0);
    expect(() => timeline.timeForFrame(-1), throwsRangeError);
    expect(() => timeline.timeForFrame(3), throwsRangeError);
  });

  test('evidence receipts preserve requested and actual times without mutable aliases', () {
    final cells = [
      const MediaContactSheetCell(
        frameIndex: 3,
        timeSeconds: 0.3,
        requestedTimeSeconds: 0.35,
        column: 1,
        row: 0,
      ),
    ];
    final sheet = MediaContactSheet(
      filePath: '/fixture/evidence.png',
      width: 140,
      height: 56,
      cells: cells,
    );
    cells.clear();
    expect(sheet.cells, hasLength(1));
    expect(sheet.cells.clear, throwsUnsupportedError);
    expect(sheet.toJson(), {
      'schemaVersion': 1,
      'filePath': '/fixture/evidence.png',
      'width': 140,
      'height': 56,
      'cells': [
        {'frameIndex': 3, 'timeSeconds': 0.3, 'requestedTimeSeconds': 0.35, 'column': 1, 'row': 0},
      ],
    });
    expect(const MediaCancelledException().toString(), 'Media operation cancelled');
  });
}
