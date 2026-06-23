import 'dart:async';
import 'dart:io';

import 'package:fluvie_cli/fluvie_cli.dart' show RenderProgress;
import 'package:fluvie_server/src/api/jobs/in_memory_job_store.dart';
import 'package:fluvie_server/src/api/jobs/job_status.dart';
import 'package:fluvie_server/src/api/jobs/job_store.dart';
import 'package:fluvie_server/src/api/jobs/render_job.dart';
import 'package:fluvie_server/src/api/jobs/render_queue.dart';
import 'package:fluvie_server/src/api/render/render_request.dart';
import 'package:fluvie_server/src/api/render/render_runner.dart';
import 'package:fluvie_server/src/api/storage/in_memory_file_store.dart';
import 'package:fluvie_server/src/api/storage/stored_object.dart';
import 'package:test/test.dart';

import '../render/fakes/fake_render_runner.dart';

const ExportOptions _noOptions = (format: null, aspect: null, quality: null, poster: null);

/// Waits until [check] holds (the queue runs jobs in the background).
Future<RenderJob> _eventually(
  InMemoryJobStore store,
  String id,
  bool Function(RenderJob) check,
) async {
  for (var i = 0; i < 200; i++) {
    final job = await store.get(id);
    if (job != null && check(job)) return job;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  throw StateError('job $id never satisfied the condition');
}

/// A [JobStore] that throws once on the first terminal-status write (simulating
/// a finalize-time disk race), delegating every other call to [_inner].
final class _FlakyJobStore implements JobStore {
  _FlakyJobStore(this._inner);

  final JobStore _inner;
  bool threw = false;

  @override
  Future<RenderJob> update(RenderJob job) {
    final terminal = job.status == JobStatus.succeeded || job.status == JobStatus.failed;
    if (terminal && !threw) {
      threw = true;
      throw StateError('simulated finalize write failure');
    }
    return _inner.update(job);
  }

  @override
  Future<RenderJob> create(RenderJob job) => _inner.create(job);
  @override
  Future<RenderJob?> get(String id) => _inner.get(id);
  @override
  Stream<RenderJob> expiredBefore(DateTime cutoff) => _inner.expiredBefore(cutoff);
  @override
  Future<void> delete(String id) => _inner.delete(id);
}

void main() {
  late InMemoryJobStore jobs;
  late InMemoryFileStore files;
  late List<Directory> workDirs;

  setUp(() {
    jobs = InMemoryJobStore();
    files = InMemoryFileStore();
    workDirs = [];
    addTearDown(() {
      for (final dir in workDirs) {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      }
    });
  });

  Future<Directory> makeWorkDir(String jobId) async {
    final dir = Directory.systemTemp.createTempSync('fluvie_server_q_');
    workDirs.add(dir);
    return dir;
  }

  RenderQueue queue(
    RenderRunner runner, {
    int concurrency = 1,
    DateTime Function()? now,
  }) => RenderQueue(
    runner: runner,
    jobStore: jobs,
    fileStore: files,
    fileTtl: const Duration(hours: 24),
    concurrency: concurrency,
    now: now,
    newId: () => 'rnd_test_${jobs.hashCode}_${DateTime.now().microsecondsSinceEpoch}',
    createWorkDir: makeWorkDir,
  );

  test('a finalize write failure releases the slot and runs the next job', () async {
    final flaky = _FlakyJobStore(jobs);
    final q = RenderQueue(
      runner: FakeRenderRunner(),
      jobStore: flaky,
      fileStore: files,
      fileTtl: const Duration(hours: 24),
      newId: () => 'rnd_${DateTime.now().microsecondsSinceEpoch}_${flaky.hashCode}',
      createWorkDir: makeWorkDir,
    );
    await q.enqueue(
      const KeyRenderRequest('demo', _noOptions),
      visibility: StoreVisibility.private,
    );
    final j2 = await q.enqueue(
      const KeyRenderRequest('demo', _noOptions),
      visibility: StoreVisibility.private,
    );

    // The first job's terminal write throws; the worker must still free its slot
    // and finish the second job (the bug left it queued forever).
    await _eventually(jobs, j2.id, (job) => job.status == JobStatus.succeeded);
    expect(flaky.threw, isTrue);
  });

  test('a successful render stores the video + poster and records the keys', () async {
    final now = DateTime.utc(2026, 6, 20, 10);
    final job =
        await queue(
          FakeRenderRunner(),
          now: () => now,
        ).enqueue(
          const KeyRenderRequest('demo', _noOptions),
          visibility: StoreVisibility.public,
        );

    expect(job.status, JobStatus.queued);
    expect(job.expiresAt, now.add(const Duration(hours: 24)));

    final done = await _eventually(jobs, job.id, (j) => j.status == JobStatus.succeeded);
    expect(done.videoKey, '${job.id}/video.mp4');
    expect(done.posterKey, '${job.id}/poster.png');
    expect(await files.stat(done.videoKey!), isNotNull);
    expect((await files.stat(done.videoKey!))!.visibility, StoreVisibility.public);
    expect(done.progress, const RenderProgress(completed: 1, total: 1));
    expect(done.startedAt, isNotNull);
    expect(done.finishedAt, isNotNull);
  });

  test('a ttl override sets the expiry', () async {
    final now = DateTime.utc(2026, 6, 20, 10);
    final job = await queue(FakeRenderRunner(), now: () => now).enqueue(
      const KeyRenderRequest('demo', _noOptions),
      visibility: StoreVisibility.private,
      ttl: const Duration(hours: 1),
    );
    expect(job.expiresAt, now.add(const Duration(hours: 1)));
  });

  test('a render exposes code and spec in the job as soon as the runner emits them', () async {
    const printed = 'Video build() => Video(scenes: const []);';
    const spec = <String, Object?>{
      'fluvieSpec': 1,
      'scenes': [
        {'duration': '2s'},
      ],
    };
    final job = await queue(FakeRenderRunner(code: printed, spec: spec)).enqueue(
      const PromptRenderRequest('a promo', null, _noOptions),
      visibility: StoreVisibility.private,
    );
    // The fake emits code+spec via onAuthored before completing; the queue
    // persists both at the same moment.
    final withCode = await _eventually(jobs, job.id, (j) => j.code != null);
    expect(withCode.code, printed);
    expect(withCode.spec, spec);
    final done = await _eventually(jobs, job.id, (j) => j.status == JobStatus.succeeded);
    expect(done.code, printed);
    expect(done.spec, spec);
  });

  test('a render with no poster records a null posterKey', () async {
    final job = await queue(FakeRenderRunner(writePoster: false)).enqueue(
      const KeyRenderRequest('demo', _noOptions),
      visibility: StoreVisibility.private,
    );
    final done = await _eventually(jobs, job.id, (j) => j.status == JobStatus.succeeded);
    expect(done.posterKey, isNull);
    expect(done.videoKey, isNotNull);
  });

  test('a RenderFailure marks the job failed with the message', () async {
    final job = await queue(
      FakeRenderRunner(error: const RenderFailure('bad spec')),
    ).enqueue(const KeyRenderRequest('demo', _noOptions), visibility: StoreVisibility.private);

    final done = await _eventually(jobs, job.id, (j) => j.status == JobStatus.failed);
    expect(done.error, 'bad spec');
  });

  test('an unexpected error fails the job with a generic message', () async {
    final job = await queue(_ThrowingRunner()).enqueue(
      const KeyRenderRequest('demo', _noOptions),
      visibility: StoreVisibility.private,
    );
    final done = await _eventually(jobs, job.id, (j) => j.status == JobStatus.failed);
    expect(done.error, 'Internal render error');
  });

  test('concurrency 1 runs jobs one at a time', () async {
    final runner = _GatedRunner();
    final q = queue(runner);
    final a = await q.enqueue(
      const KeyRenderRequest('a', _noOptions),
      visibility: StoreVisibility.private,
    );
    final b = await q.enqueue(
      const KeyRenderRequest('b', _noOptions),
      visibility: StoreVisibility.private,
    );

    await _eventually(jobs, a.id, (j) => j.status == JobStatus.running);
    expect((await jobs.get(b.id))!.status, JobStatus.queued, reason: 'b waits while a runs');
    runner.release();
    await _eventually(jobs, b.id, (j) => j.status == JobStatus.succeeded);
  });

  test('uses working defaults for now and newId', () async {
    final q = RenderQueue(
      runner: FakeRenderRunner(),
      jobStore: jobs,
      fileStore: files,
      fileTtl: const Duration(hours: 2),
      createWorkDir: makeWorkDir,
    );
    final job = await q.enqueue(
      const KeyRenderRequest('demo', _noOptions),
      visibility: StoreVisibility.private,
    );
    expect(job.id, startsWith('rnd_'));
    expect(job.expiresAt.isAfter(job.createdAt), isTrue);
  });
}

/// A runner that throws a non-[RenderFailure] error.
final class _ThrowingRunner implements RenderRunner {
  @override
  Future<RenderOutcome> run(
    RenderRequest request, {
    required Directory workDir,
    void Function(RenderProgress)? onProgress,
    void Function(String code, Map<String, Object?> spec)? onAuthored,
  }) async => throw StateError('boom');
}

/// A runner that blocks until [release] is called, to observe queuing.
final class _GatedRunner implements RenderRunner {
  final _gate = Completer<void>();
  void release() => _gate.complete();

  @override
  Future<RenderOutcome> run(
    RenderRequest request, {
    required Directory workDir,
    void Function(RenderProgress)? onProgress,
    void Function(String code, Map<String, Object?> spec)? onAuthored,
  }) async {
    await _gate.future;
    await workDir.create(recursive: true);
    final video = File('${workDir.path}/video.mp4')..writeAsBytesSync(const [0]);
    return RenderOutcome(videoPath: video.path, videoContentType: 'video/mp4');
  }
}
