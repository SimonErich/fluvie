import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

void main() {
  test('waveform rows apply delayed trim, lane mix and solo over the full timeline', () {
    final document = EditorDocument.fromJson(const {
      'fluvieSpec': 1,
      'fps': 10,
      'size': {'width': 100, 'height': 100},
      'lanes': [
        {'id': 'voice', 'kind': 'audio', 'gain': 0.5},
      ],
      'scenes': [
        {'duration': '4s'},
      ],
      'audio': [
        {
          'kind': 'music',
          'source': {'kind': 'asset', 'value': 'voice.wav'},
          'lane': 'voice',
          'at': {'kind': 'at', 'time': '1s'},
          'trim': {'from': '1s', 'to': '3s'},
        },
      ],
    });
    final timebase = VideoTimebase.of(document);
    const source = WaveformEnvelope(
      sampleRate: 10,
      durationSeconds: 4,
      buckets: [
        WaveformBucket.silent,
        WaveformBucket(min: -1, max: 1, rms: 0.5),
        WaveformBucket(min: -0.2, max: 0.2, rms: 0.1),
        WaveformBucket.silent,
      ],
    );
    final monitor = AudioMonitorController();
    addTearDown(monitor.dispose);
    Map<String, WaveformEnvelope> resolve() => timelineAudioEnvelopes(
      document,
      timebase,
      {'voice.wav': source},
      monitor: monitor,
      maxBuckets: 4,
    );
    final row = resolve()['lane:voice']!;
    expect(row.durationSeconds, 4);
    expect(row.buckets.map((b) => b.peak), [0, 0.5, 0.1, 0]);
    monitor.toggleSolo('another');
    expect(resolve()['lane:voice']!.buckets.every((b) => b.peak == 0), isTrue);
  });
}
