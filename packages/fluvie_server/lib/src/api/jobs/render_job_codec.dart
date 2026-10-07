import 'package:fluvie_cli/fluvie_cli.dart' show RenderProgress;
import 'package:fluvie_server/src/api/jobs/job_status.dart';
import 'package:fluvie_server/src/api/jobs/render_job.dart';
import 'package:fluvie_server/src/api/storage/stored_object.dart';

Map<String, Object?> encodeRenderJob(RenderJob job) => {
  'id': job.id,
  'kind': job.kind.name,
  'status': job.status.name,
  'visibility': job.visibility.name,
  'createdAtMs': job.createdAt.toUtc().millisecondsSinceEpoch,
  'expiresAtMs': job.expiresAt.toUtc().millisecondsSinceEpoch,
  'startedAtMs': job.startedAt?.toUtc().millisecondsSinceEpoch,
  'finishedAtMs': job.finishedAt?.toUtc().millisecondsSinceEpoch,
  'progress': job.progress == null
      ? null
      : {'completed': job.progress!.completed, 'total': job.progress!.total},
  'videoKey': job.videoKey,
  'posterKey': job.posterKey,
  'code': job.code,
  'spec': job.spec,
  'error': job.error,
};

RenderJob decodeRenderJob(Map<String, Object?> json) {
  final progress = json['progress'] as Map<String, Object?>?;
  return RenderJob(
    id: json['id']! as String,
    kind: RenderJobKind.values.byName(json['kind']! as String),
    status: JobStatus.values.byName(json['status']! as String),
    visibility: StoreVisibility.values.byName(json['visibility']! as String),
    createdAt: _time(json['createdAtMs'])!,
    expiresAt: _time(json['expiresAtMs'])!,
    startedAt: _time(json['startedAtMs']),
    finishedAt: _time(json['finishedAtMs']),
    progress: progress == null
        ? null
        : RenderProgress(
            completed: progress['completed']! as int,
            total: progress['total']! as int,
          ),
    videoKey: json['videoKey'] as String?,
    posterKey: json['posterKey'] as String?,
    code: json['code'] as String?,
    spec: json['spec'] as Map<String, Object?>?,
    error: json['error'] as String?,
  );
}

DateTime? _time(Object? ms) =>
    ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms as int, isUtc: true);
