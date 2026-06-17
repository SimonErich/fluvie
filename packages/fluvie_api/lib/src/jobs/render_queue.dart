import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:fluvie_api/src/jobs/job_status.dart';
import 'package:fluvie_api/src/jobs/job_store.dart';
import 'package:fluvie_api/src/jobs/render_job.dart';
import 'package:fluvie_api/src/render/render_request.dart';
import 'package:fluvie_api/src/render/render_runner.dart';
import 'package:fluvie_api/src/storage/file_store.dart';
import 'package:fluvie_api/src/storage/stored_object.dart';

/// Accepts render requests and runs them through [RenderRunner] with a bounded
/// concurrency, persisting each job's lifecycle in the [JobStore] and its
/// outputs in the [FileStore].
///
/// [enqueue] returns immediately with a queued job (HTTP 202); the work happens
/// in the background. Default concurrency is 1 because the encoder is
/// single-threaded by the determinism contract and concurrent `flutter test`
/// captures are heavy.
final class RenderQueue {
  /// Creates a queue. [now] and [newId] are injected for deterministic tests;
  /// [createWorkDir] yields a scratch directory per job.
  RenderQueue({
    required this.runner,
    required this.jobStore,
    required this.fileStore,
    required this.fileTtl,
    this.concurrency = 1,
    DateTime Function()? now,
    String Function()? newId,
    Future<Directory> Function(String jobId)? createWorkDir,
  }) : _now = now ?? _defaultNow,
       _newId = newId ?? _defaultId,
       _createWorkDir = createWorkDir ?? _defaultWorkDir;

  /// The render executor.
  final RenderRunner runner;

  /// Where job records live.
  final JobStore jobStore;

  /// Where rendered files land.
  final FileStore fileStore;

  /// Default validity applied to a render's files.
  final Duration fileTtl;

  /// How many renders run at once.
  final int concurrency;

  final DateTime Function() _now;
  final String Function() _newId;
  final Future<Directory> Function(String jobId) _createWorkDir;

  final Queue<_Pending> _pending = Queue<_Pending>();
  int _active = 0;

  /// Validates and queues [request], returning the new job. [visibility] and an
  /// optional [ttl] override come from the request; the work runs in the
  /// background and progress is polled via the job store.
  Future<RenderJob> enqueue(
    RenderRequest request, {
    required StoreVisibility visibility,
    Duration? ttl,
  }) async {
    final createdAt = _now();
    final job = RenderJob.queued(
      id: _newId(),
      kind: request.kind,
      visibility: visibility,
      createdAt: createdAt,
      expiresAt: createdAt.add(ttl ?? fileTtl),
    );
    await jobStore.create(job);
    _pending.add(_Pending(job, request));
    _pump();
    return job;
  }

  void _pump() {
    while (_active < concurrency && _pending.isNotEmpty) {
      _active++;
      // Fire-and-forget: the job's outcome is recorded in the store, not awaited.
      unawaited(_runJob(_pending.removeFirst()));
    }
  }

  Future<void> _runJob(_Pending pending) async {
    var job = pending.job.copyWith(status: JobStatus.running, startedAt: _now());
    await jobStore.update(job);
    final workDir = await _createWorkDir(job.id);
    try {
      final outcome = await runner.run(
        pending.request,
        workDir: workDir,
        onProgress: (progress) {
          job = job.copyWith(progress: progress);
          unawaited(jobStore.update(job));
        },
      );
      final keys = await _store(job, outcome);
      job = job.copyWith(
        status: JobStatus.succeeded,
        finishedAt: _now(),
        videoKey: keys.video,
        posterKey: keys.poster,
      );
    } on RenderFailure catch (failure) {
      job = job.copyWith(status: JobStatus.failed, finishedAt: _now(), error: failure.message);
    } on Object {
      job = job.copyWith(
        status: JobStatus.failed,
        finishedAt: _now(),
        error: 'Internal render error',
      );
    } finally {
      if (workDir.existsSync()) await workDir.delete(recursive: true);
      await jobStore.update(job);
      _active--;
      _pump();
    }
  }

  Future<({String video, String? poster})> _store(RenderJob job, RenderOutcome outcome) async {
    final ext = outcome.videoPath.split('.').last;
    final videoKey = '${job.id}/video.$ext';
    final video = File(outcome.videoPath);
    await fileStore.put(
      videoKey,
      video.openRead(),
      contentType: outcome.videoContentType,
      visibility: job.visibility,
      length: video.lengthSync(),
      expiresAt: job.expiresAt,
    );
    String? posterKey;
    final posterPath = outcome.posterPath;
    if (posterPath != null) {
      posterKey = '${job.id}/poster.png';
      final poster = File(posterPath);
      await fileStore.put(
        posterKey,
        poster.openRead(),
        contentType: 'image/png',
        visibility: job.visibility,
        length: poster.lengthSync(),
        expiresAt: job.expiresAt,
      );
    }
    return (video: videoKey, poster: posterKey);
  }

  static DateTime _defaultNow() => DateTime.now().toUtc();

  static int _idCounter = 0;
  static String _defaultId() => 'rnd_${_defaultNow().microsecondsSinceEpoch}_${_idCounter++}';

  // coverage:ignore-start: real temp dir; unit tests inject their own work dir
  static Future<Directory> _defaultWorkDir(String jobId) =>
      Directory.systemTemp.createTemp('fluvie_api_job_${jobId}_');
  // coverage:ignore-end
}

final class _Pending {
  _Pending(this.job, this.request);
  final RenderJob job;
  final RenderRequest request;
}
