import 'package:fluvie/src/declarative/utils/frame_range.dart';

// Shared state for FrameRange tests
FrameRange? _currentRange;
FrameRange? _anotherRange;
List<int>? _keyframes;

void setCurrentRange(FrameRange range) {
  _currentRange = range;
}

FrameRange getCurrentRange() {
  if (_currentRange == null) {
    throw StateError('No current FrameRange has been created');
  }
  return _currentRange!;
}

void setAnotherRange(FrameRange range) {
  _anotherRange = range;
}

FrameRange getAnotherRange() {
  if (_anotherRange == null) {
    throw StateError('No second FrameRange has been created');
  }
  return _anotherRange!;
}

void setKeyframes(List<int> keyframes) {
  _keyframes = keyframes;
}

List<int> getKeyframes() {
  if (_keyframes == null) {
    throw StateError('No keyframes have been generated');
  }
  return _keyframes!;
}

// Reset all state (useful for test isolation if needed)
void resetUtilitiesContext() {
  _currentRange = null;
  _anotherRange = null;
  _keyframes = null;
}
