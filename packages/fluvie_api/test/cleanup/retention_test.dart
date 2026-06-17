import 'package:fluvie_api/src/cleanup/default_retention_service.dart';
import 'package:fluvie_api/src/cleanup/retention_scheduler.dart';
import 'package:fluvie_api/src/cleanup/retention_service.dart';
import 'package:fluvie_api/src/jobs/in_memory_job_store.dart';
import 'package:fluvie_api/src/jobs/job_status.dart';
import 'package:fluvie_api/src/jobs/render_job.dart';
import 'package:fluvie_api/src/storage/in_memory_file_store.dart';
import 'package:fluvie_api/src/storage/stored_object.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 6, 20, 12);
  late InMemoryJobStore jobs;
  late InMemoryFileStore files;
  late DefaultRetentionService service;

  setUp(() {
    jobs = InMemoryJobStore();
    files = InMemoryFileStore(now: now);
    service = DefaultRetentionService(jobs, files);
  });

  Future<RenderJob> seedJob(
    String id, {
    required JobStatus status,
    required DateTime expiresAt,
    bool withFiles = true,
  }) async {
    final job = RenderJob(
      id: id,
      kind: RenderJobKind.key,
      status: status,
      visibility: StoreVisibility.private,
      createdAt: now.subtract(const Duration(days: 1)),
      expiresAt: expiresAt,
      videoKey: withFiles ? '$id/video.mp4' : null,
      posterKey: withFiles ? '$id/poster.png' : null,
    );
    await jobs.create(job);
    if (withFiles) {
      await files.put(
        '$id/video.mp4',
        Stream.value(const [1, 2, 3]),
        contentType: 'video/mp4',
        visibility: StoreVisibility.private,
        expiresAt: expiresAt,
      );
      await files.put(
        '$id/poster.png',
        Stream.value(const [9]),
        contentType: 'image/png',
        visibility: StoreVisibility.private,
        expiresAt: expiresAt,
      );
    }
    return job;
  }

  test('deletes an expired succeeded job and its files', () async {
    await seedJob(
      'old',
      status: JobStatus.succeeded,
      expiresAt: now.subtract(const Duration(hours: 1)),
    );
    await seedJob(
      'fresh',
      status: JobStatus.succeeded,
      expiresAt: now.add(const Duration(hours: 1)),
    );

    final report = await service.sweep(now: now);

    expect(report.deletedJobs, 1);
    expect(report.deletedFiles, 2);
    expect(report.freedBytes, 4); // 3 + 1 bytes
    expect(report.dryRun, isFalse);
    expect(await jobs.get('old'), isNull);
    expect(await files.stat('old/video.mp4'), isNull);
    expect(await jobs.get('fresh'), isNotNull);
  });

  test('a dry run reports but deletes nothing', () async {
    await seedJob(
      'old',
      status: JobStatus.failed,
      expiresAt: now.subtract(const Duration(hours: 1)),
    );

    final report = await service.sweep(now: now, dryRun: true);

    expect(report.deletedJobs, 1);
    expect(report.deletedFiles, 2);
    expect(report.dryRun, isTrue);
    expect(await jobs.get('old'), isNotNull, reason: 'nothing actually deleted');
    expect(await files.stat('old/video.mp4'), isNotNull);
  });

  test('never deletes a running or queued job even if expired', () async {
    await seedJob(
      'running',
      status: JobStatus.running,
      expiresAt: now.subtract(const Duration(hours: 2)),
    );
    await seedJob(
      'queued',
      status: JobStatus.queued,
      expiresAt: now.subtract(const Duration(hours: 2)),
    );

    final report = await service.sweep(now: now);

    expect(report.deletedJobs, 0);
    expect(await jobs.get('running'), isNotNull);
    expect(await jobs.get('queued'), isNotNull);
  });

  test('sweeps orphan files past their own expiry', () async {
    await files.put(
      'orphan/video.mp4',
      Stream.value(const [1, 2]),
      contentType: 'video/mp4',
      visibility: StoreVisibility.private,
      expiresAt: now.subtract(const Duration(minutes: 1)),
    );
    await files.put(
      'kept/video.mp4',
      Stream.value(const [1]),
      contentType: 'video/mp4',
      visibility: StoreVisibility.private,
      expiresAt: now.add(const Duration(hours: 1)),
    );

    final report = await service.sweep(now: now);

    expect(report.deletedFiles, 1);
    expect(report.freedBytes, 2);
    expect(await files.stat('orphan/video.mp4'), isNull);
    expect(await files.stat('kept/video.mp4'), isNotNull);
  });

  test('counts a missing file gracefully (job key without object)', () async {
    await seedJob(
      'gone',
      status: JobStatus.succeeded,
      expiresAt: now.subtract(const Duration(hours: 1)),
      withFiles: false,
    );
    final report = await service.sweep(now: now);
    expect(report.deletedJobs, 1);
    expect(report.deletedFiles, 0);
  });

  test('report serializes to JSON', () async {
    final report = await service.sweep(now: now);
    expect(report.toJson(), containsPair('scanned', 0));
    expect(report.toJson()['startedAt'], '2026-06-20T12:00:00.000Z');
  });

  group('RetentionScheduler', () {
    test('start is a no-op when the interval is zero', () {
      var swept = false;
      RetentionScheduler(
        _SweepSpy(() => swept = true),
        interval: Duration.zero,
      ).start();
      expect(swept, isFalse);
    });

    test('fires the sweep on its interval, and stop halts it', () async {
      var sweeps = 0;
      // The second start() is a no-op (already running).
      final scheduler =
          RetentionScheduler(
              _SweepSpy(() => sweeps++),
              interval: const Duration(milliseconds: 10),
              onSweep: (_) {},
            )
            ..start()
            ..start();
      await Future<void>.delayed(const Duration(milliseconds: 35));
      scheduler.stop();
      final afterStop = sweeps;
      expect(afterStop, greaterThanOrEqualTo(1));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(sweeps, afterStop, reason: 'no sweeps after stop');
    });
  });
}

/// A retention service that runs [onSweep] and returns an empty report.
final class _SweepSpy implements RetentionService {
  _SweepSpy(this.onSweep);
  final void Function() onSweep;

  @override
  Future<RetentionReport> sweep({DateTime? now, bool dryRun = false}) async {
    onSweep();
    final at = now ?? DateTime.utc(2026);
    return RetentionReport(
      scanned: 0,
      deletedFiles: 0,
      deletedJobs: 0,
      freedBytes: 0,
      dryRun: dryRun,
      startedAt: at,
      finishedAt: at,
    );
  }
}
