import 'package:fluvie/src/audio/encoding/audio_filter_graph.dart';
import 'package:fluvie/src/rendering/encoding/audio_graph_nodes.dart';
import 'package:meta/meta.dart';

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
    this.fadeInSeconds,
    this.fadeOutSeconds,
    this.fadeOutStartSeconds = 0,
  });

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

  /// How long the track ramps in from silence, in seconds; `null` for no fade.
  final double? fadeInSeconds;

  /// How long the track ramps out to silence, in seconds; `null` for no fade.
  final double? fadeOutSeconds;

  /// When the fade-out begins, in seconds (only used with [fadeOutSeconds]).
  final double fadeOutStartSeconds;

  @override
  List<String> inputArgs() => ['-i', validateAudioName(name)];

  @override
  String mapSpecifier(int inputIndex) => '$inputIndex:a';

  /// The `-filter_complex` chain for this track, reading FFmpeg input
  /// [inputIndex]'s audio stream and producing the named [label] pad.
  ///
  /// The order is fixed for determinism: optional `atrim`, then the mandatory
  /// `asetpts=PTS-STARTPTS` (so a trim restarts at zero), then optional
  /// `adelay`, then `volume`, then optional `afade` in/out.
  @override
  String filterChain({required int inputIndex, required String label}) {
    final filters = <String>[
      if (trimStartSeconds != null || trimEndSeconds != null) _atrim(),
      'asetpts=PTS-STARTPTS',
      if (delayMs > 0) 'adelay=$delayMs|$delayMs',
      'volume=${formatFilterNumber(volume)}',
      if (fadeInSeconds != null) 'afade=t=in:st=0:d=${formatFilterNumber(fadeInSeconds!)}',
      if (fadeOutSeconds != null) _fadeOut(),
    ];
    return '[$inputIndex:a]${filters.join(',')}[$label]';
  }

  String _fadeOut() {
    final start = formatFilterNumber(fadeOutStartSeconds);
    final duration = formatFilterNumber(fadeOutSeconds!);
    return 'afade=t=out:st=$start:d=$duration';
  }

  String _atrim() {
    final parts = <String>[
      if (trimStartSeconds != null) 'start=${formatFilterNumber(trimStartSeconds!)}',
      if (trimEndSeconds != null) 'end=${formatFilterNumber(trimEndSeconds!)}',
    ];
    return 'atrim=${parts.join(':')}';
  }
}
