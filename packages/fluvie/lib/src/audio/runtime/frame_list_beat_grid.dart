import 'package:fluvie/src/core/contracts/beat_grid.dart';

/// The production [BeatGrid]: an immutable, ascending list of beat frames in
/// absolute video-frame space.
///
/// This is what the spectral beat detector emits. The `Trigger.beat` resolver
/// queries it exactly as it queries the test `FakeBeatGrid`, so the timing
/// engine needs no change. Querying is a pure linear scan over the precomputed
/// frames, which keeps timing resolution deterministic.
final class FrameListBeatGrid implements BeatGrid {
  /// Creates a grid whose beats fall on [beatFrames] (must be ascending).
  FrameListBeatGrid(List<int> beatFrames) : _beatFrames = List.unmodifiable(beatFrames);

  final List<int> _beatFrames;

  /// The beat frames this grid carries, in ascending order.
  List<int> get beatFrames => _beatFrames;

  @override
  int? firstBeatAtOrAfter(int frame, {int every = 1}) {
    assert(every >= 1, 'firstBeatAtOrAfter needs every >= 1');
    for (var i = 0; i < _beatFrames.length; i += every) {
      if (_beatFrames[i] >= frame) return _beatFrames[i];
    }
    return null;
  }
}
