import 'package:fluvie_cli/fluvie_cli.dart' show RenderProgress;
import 'package:fluvie_server/src/api/jobs/job_status.dart';
import 'package:fluvie_server/src/api/storage/stored_object.dart';
import 'package:meta/meta.dart';

/// Which input produced a job: a registry key, a spec, or an AI prompt/edit.
enum RenderJobKind {
  /// A registered composition key.
  key,

  /// A serialized `VideoSpec` document.
  spec,

  /// A natural-language prompt (AI authoring).
  prompt,

  /// A base spec plus a natural-language change (AI editing).
  edit,

  /// A user-submitted Dart `Video build()` snippet (the Playground).
  code,
}

/// One render job: its lifecycle state, timing, visibility, output keys, and a
/// live progress snapshot. Immutable; transitions go through [copyWith].
@immutable
final class RenderJob {
  /// Creates a job (use [RenderJob.queued] to start one).
  const RenderJob({
    required this.id,
    required this.kind,
    required this.status,
    required this.visibility,
    required this.createdAt,
    required this.expiresAt,
    this.startedAt,
    this.finishedAt,
    this.progress,
    this.videoKey,
    this.posterKey,
    this.error,
  });

  /// Creates a freshly queued job.
  factory RenderJob.queued({
    required String id,
    required RenderJobKind kind,
    required StoreVisibility visibility,
    required DateTime createdAt,
    required DateTime expiresAt,
  }) => RenderJob(
    id: id,
    kind: kind,
    status: JobStatus.queued,
    visibility: visibility,
    createdAt: createdAt,
    expiresAt: expiresAt,
  );

  /// The opaque job id (also the storage-key prefix).
  final String id;

  /// What produced the job.
  final RenderJobKind kind;

  /// The current lifecycle state.
  final JobStatus status;

  /// Whether the output is public or private.
  final StoreVisibility visibility;

  /// When the job was created (UTC).
  final DateTime createdAt;

  /// When the job's files expire (UTC).
  final DateTime expiresAt;

  /// When the render started (UTC), or `null` while queued.
  final DateTime? startedAt;

  /// When the render finished (UTC), or `null` until done.
  final DateTime? finishedAt;

  /// Live capture progress while running, or `null` before the first frame.
  final RenderProgress? progress;

  /// The stored key of the video output, or `null` until succeeded.
  final String? videoKey;

  /// The stored key of the poster, or `null` when none was produced.
  final String? posterKey;

  /// The failure message when [status] is [JobStatus.failed].
  final String? error;

  /// Returns a copy with the given fields replaced (fields are never nulled).
  RenderJob copyWith({
    JobStatus? status,
    DateTime? startedAt,
    DateTime? finishedAt,
    RenderProgress? progress,
    String? videoKey,
    String? posterKey,
    String? error,
  }) => RenderJob(
    id: id,
    kind: kind,
    status: status ?? this.status,
    visibility: visibility,
    createdAt: createdAt,
    expiresAt: expiresAt,
    startedAt: startedAt ?? this.startedAt,
    finishedAt: finishedAt ?? this.finishedAt,
    progress: progress ?? this.progress,
    videoKey: videoKey ?? this.videoKey,
    posterKey: posterKey ?? this.posterKey,
    error: error ?? this.error,
  );
}
