import 'package:fluvie/src/audio/encoding/audio_filter_graph.dart';
import 'package:fluvie/src/audio/encoding/audio_tempo_filter.dart';
import 'package:fluvie/src/audio/encoding/resolved_audio_track.dart';
import 'package:fluvie/src/core/audio/audio_automation.dart';
import 'package:fluvie/src/core/audio/audio_time_map.dart';
import 'package:fluvie/src/rendering/encoding/audio_graph_nodes.dart';
import 'package:meta/meta.dart';

part 'audio_track_node_filters.dart';

/// One audio track in the encoder mix: a materialized source
/// file plus the per-track filter that trims, delays, gains, and fades it.
///
/// This is the real [FfmpegAudioNode] used in the mix. [inputArgs] emits a single
/// validated `-i <name>`; the heavy lifting is [filterChain], which serializes
/// an **order-stable** chain `[<i>:a]atrim,asetpts=PTS-STARTPTS,adelay,volume,
/// afade(in),afade(out)[<label>]` into the `-filter_complex` graph. Every value
/// is a number this library computes (the caller resolves frames→ms/seconds
/// against fps), so there is no string-injection vector; the file [name] is the
/// only external input and it is gated by [validateAudioName].
@immutable
final class AudioTrackNode implements FfmpegAudioNode {
  /// Creates a track over the sandbox-relative [name].
  ///
  /// [delayMs] shifts the track later (the sfx `at:` trigger frame converted to
  /// ms); [trimStartSeconds]/[trimEndSeconds] keep only that span of the file;
  /// [volume] is the linear gain; [fadeInSeconds] ramps in from `0`;
  /// [fadeOutSeconds] ramps out starting at [fadeOutStartSeconds].
  const AudioTrackNode({
    required this.name,
    this.delayMs = 0,
    this.trimStartSeconds,
    this.trimEndSeconds,
    this.volume = 1,
    this.volumeEnvelope = const [],
    this.endSeconds,
    this.fadeInSeconds,
    this.fadeOutSeconds,
    this.fadeOutStartSeconds = 0,
    this.loop = false,
    this.tempo = 1,
    this.timeMap,
  });

  /// Builds the FFmpeg node for an encoder-neutral [resolved] track, decoding the
  /// sandbox-relative [name].
  ///
  /// The single mapping from a [ResolvedAudioTrack] to its FFmpeg node, so the
  /// desktop, server, and in-browser mixes share one definition (mirrors
  /// `MobileAudioTrack.fromResolved`). Carries [ResolvedAudioTrack.loop] through,
  /// so a looping bed fills the render window.
  factory AudioTrackNode.fromResolved(ResolvedAudioTrack resolved, {required String name}) =>
      AudioTrackNode(
        name: name,
        delayMs: resolved.delayMs,
        volume: resolved.volume,
        volumeEnvelope: resolved.volumeEnvelope,
        endSeconds: resolved.endSeconds,
        trimStartSeconds: resolved.trimStartSeconds,
        trimEndSeconds: resolved.trimEndSeconds,
        fadeInSeconds: resolved.fadeInSeconds,
        fadeOutSeconds: resolved.fadeOutSeconds,
        fadeOutStartSeconds: resolved.fadeOutStartSeconds,
        loop: resolved.loop,
        tempo: resolved.tempo,
        timeMap: resolved.timeMap,
      );

  /// The sandbox-relative materialized source file this track decodes from.
  final String name;

  /// How far to shift the track later, in milliseconds (`0` plays at start).
  final int delayMs;

  /// Where in the source file playback begins, in seconds; `null` plays from 0.
  final double? trimStartSeconds;

  /// Where in the source file playback ends, in seconds; `null` plays to the end.
  final double? trimEndSeconds;

  /// The linear gain applied to the track (`1` plays as authored).
  final double volume;

  /// Resolved volume multipliers relative to the audible start.
  final List<AudioVolumePoint> volumeEnvelope;

  /// Exclusive composition end for a scene-scoped track.
  final double? endSeconds;

  /// How long the track ramps in from silence, in seconds; `null` for no fade.
  final double? fadeInSeconds;

  /// How long the track ramps out to silence, in seconds; `null` for no fade.
  final double? fadeOutSeconds;

  /// When the fade-out begins, in seconds (only used with [fadeOutSeconds]).
  final double fadeOutStartSeconds;

  /// The playback-rate multiplier applied to the stream (`1` leaves it alone).
  ///
  /// Emitted as `atempo`, which only accepts `0.5..2.0` per stage, so a rate
  /// outside that range is compiled into a chain of stages whose product is the
  /// rate — never a single clipped value, which would silently play the audio
  /// at the wrong speed.
  ///
  /// Must be finite and greater than zero. A zero or non-finite rate throws an
  /// [ArgumentError] when the chain is built: the staging maths cannot converge
  /// on one, and looping instead of throwing would hang the encoder.
  final double tempo;

  /// Integrated source clock for an authored clip speed ramp.
  final AudioTimeMap? timeMap;

  /// Whether the track loops to fill the render window (a music bed).
  ///
  /// With no trim the whole input loops at the demux level (`-stream_loop -1`).
  /// With a trim the trimmed window loops in the filter graph (`aloop`), so the
  /// repeated segment is the trim and not the whole file — otherwise a trim would
  /// clip the looped stream to one window and `-shortest` would truncate the
  /// video. Either way the encode's `-shortest` bounds the loop to the video.
  final bool loop;

  /// Whether a trim window is set (either bound).
  bool get _hasTrim => trimStartSeconds != null || trimEndSeconds != null;

  @override
  List<String> inputArgs() => [
    // Only an untrimmed loop repeats the whole demuxed input here; a trimmed loop
    // repeats the trimmed window in-filter via [filterChain]'s `aloop`.
    if (loop && !_hasTrim) ...['-stream_loop', '-1'],
    '-i',
    validateAudioName(name),
  ];

  @override
  String mapSpecifier(int inputIndex) => '$inputIndex:a';

  /// The `-filter_complex` chain for this track, reading FFmpeg input
  /// [inputIndex]'s audio stream and producing the named [label] pad.
  ///
  /// The order is fixed for determinism: optional `atrim`, then the mandatory
  /// `asetpts=PTS-STARTPTS` (so a trim restarts at zero), then `aloop` for a
  /// trimmed loop, then any `atempo` stages, then optional `adelay`, then
  /// `volume`, then optional `afade` in/out.
  ///
  /// `atempo` sits before `adelay` deliberately: the delay pads the head with
  /// silence, so retiming afterwards would compress that padding and start the
  /// track early.
  @override
  String filterChain({required int inputIndex, required String label}) {
    final filters = <String>[
      if (_hasTrim) _atrim(),
      'asetpts=PTS-STARTPTS',
      if (loop && _hasTrim) 'aloop=loop=-1:size=$_loopSampleBudget',
      // Before adelay, not after: adelay pads the head with silence, and
      // retiming the padded stream would speed the silence up too, opening a
      // delayed clip's audio earlier than its picture.
      ...timeMap == null ? _atempo() : audioTimeMapFilters(timeMap!, inputIndex),
      if (delayMs > 0) ...[
        'adelay=$delayMs|$delayMs',
        // Delay can emit leading silence with missing timestamps. Normalize
        // every sample before volume/trim/amix so that silence is retained.
        'asetpts=N/SR/TB',
      ],
      _volumeFilter(),
      if (fadeInSeconds != null) _fadeIn(),
      if (fadeOutSeconds != null) _fadeOut(),
      if (endSeconds != null) 'atrim=end=${formatFilterNumber(endSeconds!)}',
    ];
    return '[$inputIndex:a]${filters.join(',')}[$label]';
  }

  /// The `aloop` sample cap for a trimmed loop. `aloop` only buffers the samples
  /// it actually receives (the trimmed window), so this is a ceiling, not an
  /// allocation; `1 << 30` samples is ~6 hours at 48 kHz, beyond any real trim.
  static const int _loopSampleBudget = 1073741824;
}
