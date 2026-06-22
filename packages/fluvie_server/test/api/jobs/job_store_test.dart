import 'dart:io';

import 'package:fluvie_cli/fluvie_cli.dart' show RenderProgress;
import 'package:fluvie_server/src/api/jobs/file_job_store.dart';
import 'package:fluvie_server/src/api/jobs/in_memory_job_store.dart';
import 'package:fluvie_server/src/api/jobs/job_status.dart';
import 'package:fluvie_server/src/api/jobs/job_store.dart';
import 'package:fluvie_server/src/api/jobs/render_job.dart';
import 'package:fluvie_server/src/api/storage/stored_object.dart';
import 'package:test/test.dart';

void main() {
  final created = DateTime.utc(2026, 6, 20, 10);

  RenderJob queued(String id, {DateTime? expiresAt}) => RenderJob.queued(
    id: id,
    kind: RenderJobKind.key,
    visibility: StoreVisibility.private,
    createdAt: created,
    expiresAt: expiresAt ?? created.add(const Duration(hours: 24)),
  );

  // The same contract is exercised against both implementations.
  void sharedContract(String name, JobStore Function() make) {
    group(name, () {
      late JobStore store;
      setUp(() => store = make());

      test('create then get round-trips the job', () async {
        await store.create(queued('a'));
        final got = await store.get('a');
        expect(got!.id, 'a');
        expect(got.status, JobStatus.queued);
        expect(got.kind, RenderJobKind.key);
      });

      test('get returns null for an unknown id', () async {
        expect(await store.get('missing'), isNull);
      });

      test('update persists a transition with progress and output keys', () async {
        await store.create(queued('a'));
        await store.update(
          (await store.get('a'))!.copyWith(
            status: JobStatus.succeeded,
            progress: const RenderProgress(completed: 48, total: 48),
            videoKey: 'a/video.mp4',
            posterKey: 'a/poster.png',
          ),
        );
        final got = await store.get('a');
        expect(got!.status, JobStatus.succeeded);
        expect(got.progress, const RenderProgress(completed: 48, total: 48));
        expect(got.videoKey, 'a/video.mp4');
        expect(got.posterKey, 'a/poster.png');
      });

      test('expiredBefore yields only jobs at or before the cutoff', () async {
        await store.create(queued('old', expiresAt: created));
        await store.create(queued('fresh', expiresAt: created.add(const Duration(days: 2))));
        final ids = await store
            .expiredBefore(created.add(const Duration(hours: 1)))
            .map((j) => j.id)
            .toList();
        expect(ids, ['old']);
      });

      test('delete removes the job and is idempotent', () async {
        await store.create(queued('a'));
        await store.delete('a');
        expect(await store.get('a'), isNull);
        await store.delete('a');
      });
    });
  }

  sharedContract('InMemoryJobStore', InMemoryJobStore.new);
  sharedContract('FileJobStore', () {
    final dir = Directory.systemTemp.createTempSync('fluvie_server_jobs_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final JobStore store = FileJobStore(dir);
    return store;
  });

  group('FileJobStore extras', () {
    late Directory dir;
    late FileJobStore store;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('fluvie_server_jobs2_');
      store = FileJobStore(dir);
      addTearDown(() => dir.deleteSync(recursive: true));
    });

    test('reconcileInterruptedJobs flips running jobs to failed', () async {
      await store.create(queued('a').copyWith(status: JobStatus.running));
      await store.create(queued('b').copyWith(status: JobStatus.succeeded));
      await store.reconcileInterruptedJobs();
      expect((await store.get('a'))!.status, JobStatus.failed);
      expect((await store.get('a'))!.error, contains('restarted'));
      expect((await store.get('b'))!.status, JobStatus.succeeded);
    });

    test('expiredBefore is empty before anything is written', () async {
      expect(await store.expiredBefore(DateTime.utc(3000)).toList(), isEmpty);
    });

    test('survives a fresh store instance over the same directory', () async {
      await store.create(queued('a'));
      final reopened = FileJobStore(dir);
      expect((await reopened.get('a'))!.id, 'a');
    });

    test('overlapping updates of one job do not race on a shared temp file', () async {
      await store.create(queued('race'));
      final base = (await store.get('race'))!;
      // Rapid progress ticks update the same job concurrently (the queue fires
      // them unawaited); a shared temp name used to throw PathNotFoundException
      // on the second rename.
      await Future.wait([
        for (var i = 1; i <= 25; i++)
          store.update(base.copyWith(progress: RenderProgress(completed: i, total: 25))),
      ]);
      expect((await store.get('race'))!.id, 'race');
    });
  });
}
