import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:fluvie/rendering.dart' show RenderCancellation, RenderCancelledException;

/// Delivery state of one immutable queued request.
enum RenderQueuePhase {
  /// Waiting for earlier requests to finish.
  queued,

  /// Capturing or encoding through the delivery service.
  running,

  /// The requested artifact was written.
  complete,

  /// The request or its output selection was cancelled.
  cancelled,

  /// The renderer failed; following jobs still run.
  failed,
}

/// One immutable request and its observable delivery state. Payloads should be
/// snapshots: subsequent edits must not change an export already in the queue.
final class RenderQueueJob<T> {
  RenderQueueJob._(this.id, this.label, this.payload);

  /// Unique session-local job identity.
  final int id;

  /// Human-readable export preset.
  final String label;

  /// Immutable document and settings captured when queued.
  final T payload;

  /// Cooperative cancellation handed to the actual renderer.
  final RenderCancellation cancellation = RenderCancellation();
  RenderQueuePhase _phase = RenderQueuePhase.queued;
  String _message = 'Queued';
  String? _artifact;

  /// Current delivery state.
  RenderQueuePhase get phase => _phase;

  /// The latest progress or outcome message.
  String get message => _message;

  /// Saved artifact location after successful delivery.
  String? get artifact => _artifact;
}

/// Executes one request, reporting progress and honoring cancellation.
typedef QueuedRender<T> =
    Future<String?> Function(
      T payload,
      RenderCancellation cancellation,
      ValueChanged<String> onProgress,
    );

/// A session-owned sequential queue. One failure never drops later jobs;
/// cancellation is acknowledged only after the runner finishes its cleanup.
final class RenderQueue<T> extends ChangeNotifier {
  /// Creates a sequential queue using the supplied delivery runner.
  RenderQueue({required this.render});

  /// The platform runner; it owns cleanup before resolving cancellation.
  final QueuedRender<T> render;
  final List<RenderQueueJob<T>> _jobs = [];
  bool _running = false;
  bool _disposed = false;
  int _next = 0;

  /// Job history in insertion order.
  List<RenderQueueJob<T>> get jobs => List.unmodifiable(_jobs);

  /// Whether the queue is processing pending jobs.
  bool get isRunning => _running;

  /// Queues a snapshot and starts processing on the next event-loop turn.
  RenderQueueJob<T> add({required String label, required T payload}) {
    if (_disposed) throw StateError('This render queue is closed');
    final job = RenderQueueJob<T>._(++_next, label, payload);
    _jobs.add(job);
    notifyListeners();
    if (!_running) unawaited(_run());
    return job;
  }

  /// Cancels one queued or running request; finished jobs are unchanged.
  void cancel(int id) {
    final job = _jobs.where((job) => job.id == id).firstOrNull;
    if (job == null ||
        (job.phase != RenderQueuePhase.queued && job.phase != RenderQueuePhase.running)) {
      return;
    }
    job.cancellation.cancel();
    if (job.phase == RenderQueuePhase.queued) {
      job
        .._phase = RenderQueuePhase.cancelled
        .._message = 'Cancelled before rendering; no temporary files created.';
    } else {
      job._message = 'Cancelling and cleaning temporary files…';
    }
    _notify();
  }

  Future<void> _run() async {
    _running = true;
    // Give the event loop an opportunity to paint the queued state first.
    await Future<void>.delayed(Duration.zero);
    try {
      while (!_disposed) {
        final job = _jobs.where((job) => job.phase == RenderQueuePhase.queued).firstOrNull;
        if (job == null) break;
        job
          .._phase = RenderQueuePhase.running
          .._message = 'Preparing';
        _notify();
        try {
          final artifact = await render(job.payload, job.cancellation, (message) {
            if (!job.cancellation.isCancelled) job._message = message;
            _notify();
          });
          job.cancellation.throwIfCancelled();
          job
            .._artifact = artifact
            .._phase = artifact == null ? RenderQueuePhase.cancelled : RenderQueuePhase.complete
            .._message = artifact == null ? 'Output selection cancelled.' : 'Saved $artifact';
        } on RenderCancelledException {
          job
            .._phase = RenderQueuePhase.cancelled
            .._message = 'Cancelled. Temporary render files removed.';
        } on Object catch (error) {
          job
            .._phase = job.cancellation.isCancelled
                ? RenderQueuePhase.cancelled
                : RenderQueuePhase.failed
            .._message = job.cancellation.isCancelled
                ? 'Cancellation requested; cleanup failed: $error'
                : '$error';
        }
        _notify();
      }
    } finally {
      _running = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final job in _jobs) {
      job.cancellation.cancel();
    }
    super.dispose();
  }
}
