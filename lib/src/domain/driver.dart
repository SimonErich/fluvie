abstract class Driver<T> {
  T get value;
  int get frame;
}

class VideoTween extends Driver<double> {
  final int startFrame;
  final int duration;
  final double begin;
  final double end;
  final int currentFrame;

  VideoTween({
    required this.startFrame,
    required this.duration,
    required this.begin,
    required this.end,
    required this.currentFrame,
  });

  @override
  double get value {
    if (currentFrame < startFrame) return begin;
    if (currentFrame > startFrame + duration) return end;
    if (duration <= 0) return begin;
    final t = (currentFrame - startFrame) / duration;
    return begin + (end - begin) * t;
  }

  @override
  int get frame => currentFrame;
}
