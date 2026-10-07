import 'dart:async';

/// Cooperative cancellation shared by capture, encoding and delivery. The
/// owner cancels once; render stages check it before creating another artifact.
final class RenderCancellation {
  final Completer<void> _cancelled = Completer<void>();
  final Set<void Function()> _pendingStages = {};

  /// Whether cancellation has been requested.
  bool get isCancelled => _cancelled.isCompleted;

  /// Completes once cancellation is requested, so an encoder can stop promptly.
  Future<void> get whenCancelled => _cancelled.future;

  /// Idempotently requests cancellation and wakes any running encoder.
  void cancel() {
    if (isCancelled) return;
    _cancelled.complete();
    for (final cancel in _pendingStages.toList()) {
      cancel();
    }
    _pendingStages.clear();
  }

  /// Waits for one stage or returns promptly when its owner cancels.
  ///
  /// Resource backends should also observe [whenCancelled] to stop their own
  /// work. The cancellation race does not dispose caller-owned resources.
  Future<T> run<T>(Future<T> Function() operation) async {
    throwIfCancelled();
    final interrupted = Completer<T>();
    void cancelStage() => interrupted.completeError(const RenderCancelledException());
    _pendingStages.add(cancelStage);
    try {
      // Observe cancellation before the operation can synchronously cancel from
      // a Flutter lifecycle callback while its pump is still in progress.
      final result = await Future.any<T>([
        interrupted.future,
        Future<T>.microtask(() {
          throwIfCancelled();
          return operation();
        }),
      ]);
      throwIfCancelled();
      return result;
    } finally {
      // Completed stages release their listener instead of retaining one future
      // callback per frame until the whole render is cancelled.
      _pendingStages.remove(cancelStage);
    }
  }

  /// Throws the typed cancellation result rather than an encoding failure.
  void throwIfCancelled() {
    if (isCancelled) throw const RenderCancelledException();
  }
}

/// A requested cancellation. The rendering owner releases its temporary
/// artifacts before completing with this exception.
final class RenderCancelledException implements Exception {
  /// Marks a render that stopped at its owner's request.
  const RenderCancelledException();
  @override
  String toString() => 'Render cancelled';
}
