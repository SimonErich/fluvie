/// The lifecycle state of a render job.
enum JobStatus {
  /// Accepted and waiting for a render slot.
  queued,

  /// Capturing/encoding right now.
  running,

  /// Finished; the output (and poster) are stored.
  succeeded,

  /// Failed; see the job's error message.
  failed,
}
