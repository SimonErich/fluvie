import 'package:fluvie_server/src/api/jobs/render_job.dart';

/// Persists render jobs and their lifecycle transitions.
///
/// One contract over an in-memory map (single-instance/dev) and a JSON-per-file
/// store (survives restart). A horizontal deployment can add a Redis/Postgres
/// implementation behind the same interface.
abstract interface class JobStore {
  /// Stores a new [job] and returns it.
  Future<RenderJob> create(RenderJob job);

  /// The job with [id], or `null` when unknown.
  Future<RenderJob?> get(String id);

  /// Persists an updated [job] and returns it.
  Future<RenderJob> update(RenderJob job);

  /// Every job whose `expiresAt` is at or before [cutoff], for retention.
  Stream<RenderJob> expiredBefore(DateTime cutoff);

  /// Deletes the job with [id] (idempotent).
  Future<void> delete(String id);
}
