import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

void main() {
  test('jobs keep order and a failed render does not discard following jobs', () async {
    final calls = <int>[];
    final done = Completer<void>();
    final queue = RenderQueue<int>(
      render: (payload, cancellation, progress) async {
        calls.add(payload);
        progress('Encoding $payload');
        if (payload == 2) throw StateError('encoder refused');
        return '$payload.mp4';
      },
    );
    addTearDown(queue.dispose);
    queue.addListener(() {
      if (queue.jobs.length == 3 &&
          queue.jobs.last.phase == RenderQueuePhase.complete &&
          !done.isCompleted) {
        done.complete();
      }
    });
    for (final value in [1, 2, 3]) {
      queue.add(label: '$value', payload: value);
    }
    await done.future;
    expect(calls, [1, 2, 3]);
    expect(queue.jobs.map((job) => job.phase), [
      RenderQueuePhase.complete,
      RenderQueuePhase.failed,
      RenderQueuePhase.complete,
    ]);
    expect(queue.jobs.last.artifact, '3.mp4');
  });

  test('cancellation awaits runner cleanup and continues with the next job', () async {
    final started = Completer<void>();
    final cleanup = Completer<void>();
    final finished = Completer<void>();
    final queue = RenderQueue<int>(
      render: (payload, cancellation, progress) async {
        if (payload == 1) {
          started.complete();
          await cancellation.whenCancelled;
          await cleanup.future;
          cancellation.throwIfCancelled();
        }
        return '$payload.mp4';
      },
    );
    addTearDown(queue.dispose);
    final first = queue.add(label: 'First', payload: 1);
    queue
      ..add(label: 'Second', payload: 2)
      ..addListener(() {
        if (queue.jobs.last.phase == RenderQueuePhase.complete && !finished.isCompleted) {
          finished.complete();
        }
      });
    await started.future;
    queue.cancel(first.id);
    expect(first.phase, RenderQueuePhase.running);
    expect(first.message, contains('cleaning'));
    cleanup.complete();
    await finished.future;
    expect(first.phase, RenderQueuePhase.cancelled);
    expect(queue.jobs.last.phase, RenderQueuePhase.complete);
  });

  test('queued cancellation avoids rendering and output dismissal leaves no artifact', () async {
    final calls = <int>[];
    final idle = Completer<void>();
    final queue = RenderQueue<int>(
      render: (payload, cancellation, progress) async {
        calls.add(payload);
        return null;
      },
    );
    addTearDown(queue.dispose);
    final skipped = queue.add(label: 'Skipped', payload: 1);
    queue.cancel(skipped.id);
    final dismissed = queue.add(label: 'Dismissed', payload: 2);
    queue.addListener(() {
      if (!queue.isRunning && !idle.isCompleted) idle.complete();
    });
    expect(() => queue.jobs.clear(), throwsUnsupportedError);
    await idle.future;
    expect(calls, [2]);
    expect(skipped.message, contains('before rendering'));
    expect(dismissed.phase, RenderQueuePhase.cancelled);
    expect(dismissed.message, 'Output selection cancelled.');
    expect(dismissed.artifact, isNull);
    queue
      ..cancel(-1)
      ..cancel(dismissed.id);
    expect(dismissed.message, 'Output selection cancelled.');
  });

  test('a cancellation cleanup failure is reported honestly and the queue continues', () async {
    final started = Completer<void>();
    final idle = Completer<void>();
    final queue = RenderQueue<int>(
      render: (payload, cancellation, progress) async {
        if (payload == 1) {
          started.complete();
          await cancellation.whenCancelled;
          progress('Obsolete encoder progress');
          throw StateError('Temporary directory is busy');
        }
        return 'next.mp4';
      },
    );
    addTearDown(queue.dispose);
    final cancelled = queue.add(label: 'Cancel', payload: 1);
    queue
      ..add(label: 'Continue', payload: 2)
      ..addListener(() {
        if (!queue.isRunning && !idle.isCompleted) idle.complete();
      });
    await started.future;
    queue.cancel(cancelled.id);
    await idle.future;
    expect(cancelled.phase, RenderQueuePhase.cancelled);
    expect(cancelled.message, contains('cleanup failed'));
    expect(cancelled.message, contains('Temporary directory is busy'));
    expect(queue.jobs.last.artifact, 'next.mp4');
  });

  test('closing an active queue cancels cleanup and never starts pending work', () async {
    final started = Completer<void>();
    final cleaned = Completer<void>();
    final calls = <int>[];
    final queue = RenderQueue<int>(
      render: (payload, cancellation, progress) async {
        calls.add(payload);
        started.complete();
        await cancellation.whenCancelled;
        cleaned.complete();
        cancellation.throwIfCancelled();
        return null;
      },
    );
    final active = queue.add(label: 'Active', payload: 1);
    final pending = queue.add(label: 'Pending', payload: 2);
    await started.future;
    queue.dispose();
    await cleaned.future;
    await Future<void>.delayed(Duration.zero);
    expect(calls, [1]);
    expect(active.cancellation.isCancelled, isTrue);
    expect(pending.cancellation.isCancelled, isTrue);
    expect(queue.isRunning, isFalse);
    expect(() => queue.add(label: 'Closed', payload: 3), throwsStateError);
  });
}
