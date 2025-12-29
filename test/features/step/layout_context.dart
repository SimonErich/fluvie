import 'package:flutter/widgets.dart';

// Shared state for layout widget tests
Widget? _currentWidget;
int _currentFrame = 0;
int? _startFrame;
int? _endFrame;
int? _fadeInFrames;
int? _fadeOutFrames;

void setCurrentWidget(Widget widget) {
  _currentWidget = widget;
}

Widget getCurrentWidget() {
  if (_currentWidget == null) {
    throw StateError('No current widget has been created');
  }
  return _currentWidget!;
}

void setCurrentFrame(int frame) {
  _currentFrame = frame;
}

int getCurrentFrame() {
  return _currentFrame;
}

void setStartFrame(int frame) {
  _startFrame = frame;
}

int? getStartFrame() {
  return _startFrame;
}

void setEndFrame(int frame) {
  _endFrame = frame;
}

int? getEndFrame() {
  return _endFrame;
}

void setFadeInFrames(int frames) {
  _fadeInFrames = frames;
}

int? getFadeInFrames() {
  return _fadeInFrames;
}

void setFadeOutFrames(int frames) {
  _fadeOutFrames = frames;
}

int? getFadeOutFrames() {
  return _fadeOutFrames;
}

// Reset all state (useful for test isolation if needed)
void resetLayoutContext() {
  _currentWidget = null;
  _currentFrame = 0;
  _startFrame = null;
  _endFrame = null;
  _fadeInFrames = null;
  _fadeOutFrames = null;
}
