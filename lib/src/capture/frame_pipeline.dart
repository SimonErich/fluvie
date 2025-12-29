import 'dart:async';
import 'dart:typed_data';

/// A producer-consumer pipeline for frame data.
///
/// This class enables parallel frame capture and FFmpeg writing by buffering
/// captured frames. The producer (frame capture) can run ahead while the
/// consumer (FFmpeg writer) processes previous frames.
///
/// The buffer has a maximum size to prevent unbounded memory growth. When the
/// buffer is full, [addFrame] will wait until space is available.
class FramePipeline {
  final StreamController<Uint8List> _frameController;
  final int maxBufferSize;
  int _bufferedFrames = 0;
  final Completer<void> _allFramesConsumed = Completer<void>();
  bool _closed = false;

  /// Creates a frame pipeline with the specified buffer size.
  ///
  /// [maxBufferSize] controls how many frames can be queued before
  /// [addFrame] blocks. A larger buffer allows more parallelism but
  /// uses more memory. For 1080p video at 4 bytes per pixel, each
  /// frame is ~8MB, so a buffer of 5 frames uses ~40MB.
  FramePipeline({this.maxBufferSize = 5})
    : _frameController = StreamController<Uint8List>();

  /// Stream of frame bytes for the consumer to process.
  Stream<Uint8List> get frames => _frameController.stream;

  /// Whether the pipeline has been closed.
  bool get isClosed => _closed;

  /// Current number of frames in the buffer.
  int get bufferedFrames => _bufferedFrames;

  /// Adds a frame to the pipeline.
  ///
  /// If the buffer is full, this method will wait until the consumer
  /// processes a frame and creates space.
  ///
  /// Throws [StateError] if the pipeline has been closed.
  Future<void> addFrame(Uint8List bytes) async {
    if (_closed) {
      throw StateError('Cannot add frame to closed pipeline');
    }

    // Wait if buffer is full
    while (_bufferedFrames >= maxBufferSize) {
      // Short delay to avoid busy-waiting
      await Future.delayed(const Duration(milliseconds: 1));
      if (_closed) {
        throw StateError('Pipeline closed while waiting to add frame');
      }
    }

    _bufferedFrames++;
    _frameController.add(bytes);
  }

  /// Notifies the pipeline that a frame has been consumed.
  ///
  /// Call this after processing each frame from [frames] to allow
  /// more frames to be added to the buffer.
  void frameConsumed() {
    _bufferedFrames--;
    if (_closed && _bufferedFrames == 0) {
      _allFramesConsumed.complete();
    }
  }

  /// Closes the pipeline, signaling that no more frames will be added.
  ///
  /// Returns a Future that completes when all buffered frames have been
  /// consumed (i.e., when [frameConsumed] has been called for each frame).
  Future<void> close() async {
    _closed = true;
    await _frameController.close();

    // If there are still buffered frames, wait for them to be consumed
    if (_bufferedFrames > 0) {
      await _allFramesConsumed.future;
    }
  }
}
