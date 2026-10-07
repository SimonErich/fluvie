part of 'media_repository.dart';

extension _AudioWindows on MediaRepository {
  Future<void> _resolveAudioWindows(
    Iterable<AudioAnalysisWindow> windows, {
    required BeatDetectionService beatDetector,
    required FrequencyAnalyzer analyzer,
  }) async {
    for (final window in windows) {
      if (_windowBands.containsKey(window)) continue;
      final path = _audioPaths[window.source] ?? await _materializeAudio(window.source);
      _audioPaths[window.source] = path;
      final source = AudioSource.file(path);
      final offset = (window.sourceStart.inMicroseconds * window.fps / 1000000).round();
      final rangedBeats = beatDetector is RangedBeatDetectionService;
      final grid = rangedBeats
          ? await beatDetector.detectRange(
              source,
              start: window.sourceStart,
              fps: window.fps,
              totalFrames: window.sourceFrames,
            )
          : await beatDetector.detect(
              source,
              fps: window.fps,
              totalFrames: offset + window.sourceFrames,
            );
      final rangedBands = analyzer is RangedFrequencyAnalyzer;
      final RangedBandAnalysis analysis;
      if (rangedBands) {
        analysis = await analyzer.analyzeRange(
          source,
          start: window.sourceStart,
          fps: window.fps,
          totalFrames: window.sourceFrames,
        );
      } else {
        final table = await analyzer.analyze(
          source,
          fps: window.fps,
          totalFrames: offset + window.sourceFrames,
        );
        analysis = (
          table: table,
          duration: Duration(
            microseconds:
                (window.sourceFrames.clamp(
                          0,
                          (table.totalFrames - offset).clamp(0, table.totalFrames),
                        ) *
                        1000000 /
                        window.fps)
                    .round(),
          ),
        );
      }
      final table = analysis.table;
      final period = analysis.duration.inMicroseconds * window.fps / 1000000;
      final tableOffset = rangedBands ? 0 : offset;
      final length = window.sourceFrames.clamp(
        0,
        table.totalFrames - tableOffset < 0 ? 0 : table.totalFrames - tableOffset,
      );
      if (length > 0 && period <= 0) {
        throw StateError('A nonempty ranged band table requires a positive duration.');
      }
      final beats = <int>[];
      var cursor = rangedBeats ? 0 : offset;
      final limit = cursor + length;
      while (cursor < limit) {
        final beat = grid.firstBeatAtOrAfter(cursor);
        if (beat == null || beat >= limit) break;
        if (beat < cursor) throw StateError('BeatGrid must advance on the requested clock.');
        beats.add(beat - (rangedBeats ? 0 : offset));
        cursor = beat + 1;
      }
      final absoluteBeats = <int>[];
      if (length > 0 && period > 0 && beats.isNotEmpty) {
        for (var cycle = window.startFrame.toDouble(); cycle < window.endFrame; cycle += period) {
          for (final beat in beats) {
            if ((cycle + beat).round() < window.endFrame) absoluteBeats.add((cycle + beat).round());
          }
          if (!window.loop) break;
        }
      }
      _windowBeats[window] = FrameListBeatGrid(absoluteBeats.toSet().toList());
      _windowBands[window] = BandTable({
        for (final band in AudioBand.values)
          band: Float64List.fromList([
            for (var frame = 0; frame <= window.endFrame; frame++)
              if (length == 0 ||
                  frame < window.startFrame ||
                  frame >= window.endFrame ||
                  (!window.loop && frame - window.startFrame >= length))
                0
              else
                table.energyAt(
                  tableOffset + ((frame - window.startFrame) % period).round().clamp(0, length - 1),
                  band,
                ),
          ]),
      });
    }
  }
}
