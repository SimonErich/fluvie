import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie/src/audio/encoding/audio_track_node.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

void main() {
  test('decibel conversions cover silence, unity, attenuation and boost', () {
    expect(decibelsToGain(double.negativeInfinity), 0);
    expect(decibelsToGain(0), 1);
    expect(decibelsToGain(-6.020599913), closeTo(0.5, 1e-9));
    expect(decibelsToGain(6.020599913), closeTo(2, 1e-9));
    expect(gainToDecibels(0), double.negativeInfinity);
    expect(gainToDecibels(0.5), closeTo(-6.020599913, 1e-9));
  });
  test('meters read silence, full scale and automation ramp without devices', () {
    const envelope = WaveformEnvelope(
      buckets: [WaveformBucket(min: -1, max: 1, rms: 0.5)],
      sampleRate: 48000,
      durationSeconds: 3,
    );
    const track = ResolvedAudioTrack(
      source: 'a',
      delayMs: 1000,
      volume: 0.5,
      volumeEnvelope: [AudioVolumePoint(0, 0), AudioVolumePoint(1, 1)],
    );
    expect(meterTrack(track: track, envelope: envelope, seconds: 0).peak, 0);
    final middle = meterTrack(track: track, envelope: envelope, seconds: 1.5);
    expect(middle.peak, 0.25);
    expect(middle.rms, 0.125);
    expect(meterTrack(track: track, envelope: envelope, seconds: 2).peak, 0.5);
    expect(meterTrack(track: track, envelope: envelope, seconds: 2, monitorGain: 0).peak, 0);
  });
  test('ducking writes attack hold release as one undoable ordinary envelope', () {
    final document = EditorDocument.fromJson(const {
      'fluvieSpec': 1,
      'fps': 10,
      'size': {'width': 320, 'height': 180},
      'scenes': [
        {'duration': '10s'},
      ],
      'audio': [
        {
          'kind': 'music',
          'source': {'kind': 'asset', 'value': 'bed.wav'},
        },
      ],
    });
    final history = DocumentHistory(document);
    addTearDown(history.dispose);
    final envelope = duckingAutomation(
      presence: [const FrameSpan(20, 40)],
      target: const FrameSpan(0, 100),
      fps: 10,
      attenuationDb: -6.020599913,
      attackSeconds: 1,
      holdSeconds: 1,
      releaseSeconds: 2,
    );
    final points = decodeAudioAutomation(envelope).resolve(fps: 10, windowFrames: 100);
    expect(audioVolumeAt(points, 0), 1);
    expect(audioVolumeAt(points, 1), 1);
    expect(audioVolumeAt(points, 2), closeTo(0.5, 1e-9));
    expect(audioVolumeAt(points, 5), closeTo(0.5, 1e-9));
    expect(audioVolumeAt(points, 6), closeTo(0.75, 1e-9));
    expect(audioVolumeAt(points, 7), 1);
    history.dispatch(
      DuckAudioTracksCommand(envelopes: [(scene: null, index: 0, automation: envelope)]),
    );
    final video = history.document.spec.build();
    final mix = resolveAudioMix(video: video, fps: 10, totalFrames: 100);
    expect(
      AudioTrackNode.fromResolved(
        mix.tracks.single,
        name: 'a',
      ).filterChain(inputIndex: 0, label: 'a'),
      contains(':eval=frame'),
    );
    history.undo();
    expect(history.document.renderDigest, document.renderDigest);
    expect(history.canUndo, isFalse);
    history.redo();
    expect(history.document.spec.audio.single.automation.isEmpty, isFalse);
  });
  test('overlapping triggers do not let the target rise between them', () {
    final points = decodeAudioAutomation(
      duckingAutomation(
        presence: [const FrameSpan(10, 30), const FrameSpan(25, 45)],
        target: const FrameSpan(0, 60),
        fps: 10,
        attenuationDb: -20,
        attackSeconds: 0.5,
        holdSeconds: 0,
        releaseSeconds: 1,
      ),
    ).resolve(fps: 10, windowFrames: 60);
    for (var f = 10; f <= 45; f++) {
      expect(audioVolumeAt(points, f / 10), closeTo(0.1, 1e-9));
    }
  });
  test('solo monitoring never alters document or export', () {
    final doc = EditorDocument.fromJson(const {
      'fluvieSpec': 1,
      'fps': 30,
      'size': {'width': 320, 'height': 180},
      'scenes': [
        {'duration': '2s'},
      ],
      'audio': [
        {
          'kind': 'music',
          'source': {'kind': 'asset', 'value': 'a.wav'},
          'lane': 'a',
        },
      ],
      'lanes': [
        {'id': 'a', 'kind': 'audio'},
        {'id': 'b', 'kind': 'audio'},
      ],
    });
    final monitor = AudioMonitorController();
    addTearDown(monitor.dispose);
    final before = doc.renderDigest;
    monitor.toggleSolo('b');
    expect(monitor.gainForLane('a'), 0);
    expect(doc.renderDigest, before);
    final mix = resolveAudioMix(video: doc.spec.build(), fps: 30, totalFrames: 60);
    expect(mix.tracks.single.volume, 1);
  });
}
