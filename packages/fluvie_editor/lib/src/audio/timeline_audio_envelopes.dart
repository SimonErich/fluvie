import 'dart:math' as math;

import 'package:fluvie/rendering.dart' show ClipMetadata, WaveformBucket, WaveformEnvelope;
import 'package:fluvie_editor/src/audio/audio_meter.dart';
import 'package:fluvie_editor/src/audio/audio_monitor_controller.dart';
import 'package:fluvie_editor/src/audio/audio_track_view.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/video_mode/video_timebase.dart';

/// Reprojects cached source waveforms onto absolute timeline rows, applying
/// placement, trim, rate/ramp, gain, fades, automation and optional solo state.
/// Output is bounded to [maxBuckets] columns per row. Columns are level
/// estimates from three samples per overlapping track; combined peaks are a
/// conservative phase-independent sum at each sample, not device meters.
Map<String, WaveformEnvelope> timelineAudioEnvelopes(
  EditorDocument document,
  VideoTimebase timebase,
  Map<String, WaveformEnvelope> sourceEnvelopes, {
  Map<String, ClipMetadata> clipMetadata = const {},
  AudioMonitorController? monitor,
  int maxBuckets = 2048,
}) {
  if (maxBuckets < 1 || maxBuckets > 16384) throw ArgumentError.value(maxBuckets, 'maxBuckets');
  if (sourceEnvelopes.isEmpty || timebase.totalFrames <= 0) return const {};
  final tracks = audioTrackViews(document, timebase, clipMetadata: clipMetadata);
  final lanes = document.spec.lanes.map((lane) => lane.id).toSet();
  final groups = <String, List<AudioTrackView>>{};
  for (final track in tracks) {
    if (!sourceEnvelopes.containsKey(track.sourceKey)) continue;
    final lane = track.spec.lane;
    final row = lane != null && lanes.contains(lane)
        ? 'lane:$lane'
        : track.elementId != null
        ? '${track.scene == null ? 'overlay-track' : 'el-track'}:${track.elementId}'
        : track.scene == null
        ? 'audio-track:v:${track.index}'
        : 'audio-track:s:${track.scene}:${track.index}';
    (groups[row] ??= []).add(track);
  }
  final count = math.min(timebase.totalFrames, maxBuckets);
  final duration = timebase.totalFrames / timebase.fps;
  return {
    for (final entry in groups.entries)
      entry.key: WaveformEnvelope(
        durationSeconds: duration,
        sampleRate: timebase.fps,
        buckets: [
          for (var bucket = 0; bucket < count; bucket++)
            _bucket(
              entry.value,
              sourceEnvelopes,
              bucket * duration / count,
              (bucket + 1) * duration / count,
              timebase.fps,
              monitor,
            ),
        ],
      ),
  };
}

WaveformBucket _bucket(
  List<AudioTrackView> tracks,
  Map<String, WaveformEnvelope> sources,
  double start,
  double end,
  int fps,
  AudioMonitorController? monitor,
) {
  final levels = <AudioMeterLevel>[];
  for (final track in tracks) {
    final from = math.max(start, track.span.start / fps);
    final to = math.min(end, track.span.end / fps);
    if (to <= from) continue;
    var peak = 0.0;
    var power = 0.0;
    for (final fraction in const [0.0, 0.5, 0.999999]) {
      final level = meterTrack(
        track: track.resolved,
        envelope: sources[track.sourceKey]!,
        seconds: from + (to - from) * fraction,
        monitorGain: monitor?.gainForLane(track.spec.lane) ?? 1,
      );
      peak = math.max(peak, level.peak);
      power += level.rms * level.rms;
    }
    levels.add(
      AudioMeterLevel(peak: peak, rms: math.sqrt(power / 3 * (to - from) / (end - start))),
    );
  }
  final mix = AudioMeterLevel.mix(levels);
  return WaveformBucket(min: -mix.peak, max: mix.peak, rms: mix.rms);
}
