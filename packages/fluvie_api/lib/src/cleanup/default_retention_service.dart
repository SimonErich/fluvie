import 'package:fluvie_api/src/cleanup/retention_service.dart';
import 'package:fluvie_api/src/jobs/job_status.dart';
import 'package:fluvie_api/src/jobs/job_store.dart';
import 'package:fluvie_api/src/storage/file_store.dart';

/// The default [RetentionService] over a [JobStore] and a [FileStore].
///
/// A sweep deletes finished jobs whose `expiresAt` has passed (and their
/// files), then makes a second pass over the store for orphan objects past
/// their own expiry. Still-running and queued jobs are left alone so a long
/// render is never cut off. `now` is injectable, so tests are clock-free.
final class DefaultRetentionService implements RetentionService {
  /// Creates the service over [jobStore] and [fileStore].
  const DefaultRetentionService(this.jobStore, this.fileStore);

  /// Where job records live.
  final JobStore jobStore;

  /// Where rendered files live.
  final FileStore fileStore;

  @override
  Future<RetentionReport> sweep({DateTime? now, bool dryRun = false}) async {
    final at = (now ?? DateTime.now()).toUtc();
    final deletedKeys = <String>{};
    var scanned = 0;
    var deletedFiles = 0;
    var deletedJobs = 0;
    var freedBytes = 0;

    await for (final job in jobStore.expiredBefore(at)) {
      scanned++;
      if (job.status == JobStatus.running || job.status == JobStatus.queued) continue;
      for (final key in [job.videoKey, job.posterKey].whereType<String>()) {
        final stat = await fileStore.stat(key);
        if (stat == null) continue;
        freedBytes += stat.bytes;
        deletedFiles++;
        deletedKeys.add(key);
        if (!dryRun) await fileStore.delete(key);
      }
      deletedJobs++;
      if (!dryRun) await jobStore.delete(job.id);
    }

    await for (final object in fileStore.list()) {
      if (deletedKeys.contains(object.key) || !object.isExpiredAt(at)) continue;
      scanned++;
      freedBytes += object.bytes;
      deletedFiles++;
      if (!dryRun) await fileStore.delete(object.key);
    }

    return RetentionReport(
      scanned: scanned,
      deletedFiles: deletedFiles,
      deletedJobs: deletedJobs,
      freedBytes: freedBytes,
      dryRun: dryRun,
      startedAt: at,
      finishedAt: at,
    );
  }
}
