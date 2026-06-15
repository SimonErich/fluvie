import 'package:fluvie/src/core/contracts/beat_grid.dart';

/// An in-memory [BeatGrid] over a fixed list of beat frames.
///
/// Stands in for the real beat-detection grid so the trigger resolver can be
/// tested deterministically.
class FakeBeatGrid implements BeatGrid {
  /// Creates a grid whose beats fall exactly on [beatFrames] (ascending).
  FakeBeatGrid(List<int> beatFrames) : _beatFrames = List.unmodifiable(beatFrames);

  /// Creates a metronome grid: beats at `0, frames, 2 * frames, …` strictly
  /// before [totalFrames].
  FakeBeatGrid.everyInterval(int frames, {required int totalFrames})
    : assert(frames >= 1, 'FakeBeatGrid.everyInterval needs frames >= 1'),
      _beatFrames = List.unmodifiable([for (var f = 0; f < totalFrames; f += frames) f]);

  final List<int> _beatFrames;

  @override
  int? firstBeatAtOrAfter(int frame, {int every = 1}) {
    assert(every >= 1, 'firstBeatAtOrAfter needs every >= 1');
    for (var i = 0; i < _beatFrames.length; i += every) {
      if (_beatFrames[i] >= frame) return _beatFrames[i];
    }
    return null;
  }
}
