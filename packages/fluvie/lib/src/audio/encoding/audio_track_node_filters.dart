part of 'audio_track_node.dart';

extension _AudioTrackFilters on AudioTrackNode {
  /// The `atempo` stages whose product is [tempo], or nothing at rate 1.
  ///
  /// Each stage stays inside FFmpeg's documented `0.5..2.0` range: a rate above
  /// it is halved into repeated 2.0 stages, below it doubled into 0.5 stages,
  /// and whatever remains rides the final stage.
  List<String> _atempo() {
    if (tempo == 1) return const [];
    if (tempo <= 0 || !tempo.isFinite) {
      // Guarded before the loops, not inside them: 0 / 0.5 is 0 and inf / 2 is
      // inf, so either would spin forever growing the stage list rather than
      // failing. A caller that produced one has a bug worth seeing.
      throw ArgumentError.value(
        tempo,
        'tempo',
        'must be a finite rate greater than zero',
      );
    }
    final stages = <double>[];
    var remaining = tempo;
    while (remaining > 2.0) {
      stages.add(2);
      remaining /= 2;
    }
    while (remaining < 0.5) {
      stages.add(0.5);
      remaining /= 0.5;
    }
    stages.add(remaining);
    return [for (final stage in stages) 'atempo=${formatFilterNumber(stage)}'];
  }

  /// The `afade` in stage, anchored where the track actually starts.
  ///
  /// `adelay` pads the head with real silence and `afade` measures `st` from
  /// the start of its own input, so a fade at `st=0` on a delayed track would
  /// ramp the padding and let the audio enter at full volume.
  String _volumeFilter() {
    if (volumeEnvelope.isEmpty) return 'volume=${formatFilterNumber(volume)}';
    for (var i = 0; i < volumeEnvelope.length; i++) {
      final point = volumeEnvelope[i];
      if (!point.seconds.isFinite ||
          !point.value.isFinite ||
          (i > 0 && point.seconds <= volumeEnvelope[i - 1].seconds)) {
        throw ArgumentError('Volume envelope must contain finite, strictly ordered samples');
      }
    }
    String number(double v) => formatFilterNumber(v);
    final clock = delayMs == 0 ? 't' : '(t-${number(delayMs / 1000)})';
    String segment(int i) {
      final a = volumeEnvelope[i];
      final b = volumeEnvelope[i + 1];
      final start = number(a.value.clamp(0.0, 1.0) * volume);
      final delta = (b.value.clamp(0.0, 1.0) - a.value.clamp(0.0, 1.0)) * volume;
      if (delta == 0) return start;
      return '$start+${number(delta)}*($clock-${number(a.seconds)})/${number(b.seconds - a.seconds)}';
    }

    // Balanced decision tree keeps long sampled curves below FFmpeg's parser
    // recursion limit; only numbers generated here can enter the expression.
    String tree(int lo, int hi) {
      if (lo == hi) return segment(lo);
      final mid = (lo + hi) ~/ 2;
      return 'if(lt($clock,${number(volumeEnvelope[mid + 1].seconds)}),${tree(lo, mid)},${tree(mid + 1, hi)})';
    }

    final first = volumeEnvelope.first;
    final last = volumeEnvelope.last;
    final expression = volumeEnvelope.length == 1
        ? number(first.value.clamp(0.0, 1.0) * volume)
        : 'if(lte($clock,${number(first.seconds)}),${number(first.value.clamp(0.0, 1.0) * volume)},if(gte($clock,${number(last.seconds)}),${number(last.value.clamp(0.0, 1.0) * volume)},${tree(0, volumeEnvelope.length - 2)}))';
    return "volume='$expression':eval=frame";
  }

  String _fadeIn() {
    final start = formatFilterNumber(delayMs / 1000);
    return 'afade=t=in:st=$start:d=${formatFilterNumber(fadeInSeconds!)}';
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
