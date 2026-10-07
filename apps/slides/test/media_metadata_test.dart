import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:slides/editor/media_metadata.dart';

void main() {
  test('container metadata preserves fractional video rate and ignores invalid values', () {
    final result = MediaMetadata.fromProbe({
      'streams': [
        {
          'codec_type': 'video',
          'width': 1920,
          'height': 1080,
          'avg_frame_rate': '30000/1001',
          'duration': '2.5025',
        },
      ],
    }, audio: false);
    expect(result.fps, closeTo(29.97002997, 0.000001));
    expect(result.duration, '2.5025s');
    expect(result.width, 1920);
    expect(
      MediaMetadata.fromProbe({
        'streams': [
          {'codec_type': 'video', 'avg_frame_rate': '0/0', 'duration': 'NaN'},
        ],
      }, audio: false).duration,
      isNull,
    );
  });
  test('a timed audio asset uses a millisecond source marking clock', () {
    final result = MediaMetadata.fromProbe({
      'streams': [
        {'codec_type': 'audio'},
      ],
      'format': {'duration': '4.25'},
    }, audio: true);
    expect(result.fps, 1000);
    expect(result.duration, '4.25s');
  });
  test('import metadata reaches the reusable bin without affecting the render digest', () {
    final doc = EditorDocument.fromJson(const {
      'fluvieSpec': 1,
      'size': {'width': 320, 'height': 180},
      'fps': 30,
      'scenes': [
        {'duration': '2s', 'children': <Object?>[]},
      ],
    });
    final entry = storeEntryFor(
      doc,
      const MediaPick(
        source: {'kind': 'file', 'value': '/clip.mp4'},
        isVideo: true,
        name: 'clip.mp4',
        duration: '2s',
        fps: 24,
        width: 640,
        height: 360,
      ),
    )!;
    expect(entry.durationFrames, 48);
    expect(entry.width, 640);
    final next = AddMediaEntryCommand(entry: entry).apply(doc);
    expect(next.renderDigest, doc.renderDigest);
    final renamed = UpdateMediaEntryCommand(entry: entry.copyWith(folder: 'B roll')).apply(next);
    expect(renamed.mediaEntries.single.folder, 'B roll');
    expect(renamed.renderDigest, doc.renderDigest);
  });
}
