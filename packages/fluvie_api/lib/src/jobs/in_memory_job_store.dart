import 'package:fluvie_api/src/jobs/job_store.dart';
import 'package:fluvie_api/src/jobs/render_job.dart';

/// An in-memory [JobStore]: jobs live in a map and are lost on restart. The
/// default for single-instance/dev runs and the fake for tests.
final class InMemoryJobStore implements JobStore {
  final Map<String, RenderJob> _jobs = {};

  @override
  Future<RenderJob> create(RenderJob job) async => _jobs[job.id] = job;

  @override
  Future<RenderJob?> get(String id) async => _jobs[id];

  @override
  Future<RenderJob> update(RenderJob job) async => _jobs[job.id] = job;

  @override
  Stream<RenderJob> expiredBefore(DateTime cutoff) => Stream.fromIterable(
    // Snapshot so a caller can delete during iteration.
    _jobs.values.where((j) => !j.expiresAt.isAfter(cutoff)).toList(),
  );

  @override
  Future<void> delete(String id) async => _jobs.remove(id);
}
