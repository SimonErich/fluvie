import 'dart:convert';
import 'dart:io';

import 'package:fluvie_cli/fluvie_cli.dart' show RenderProgress;
import 'package:fluvie_server/src/api/jobs/job_status.dart';
import 'package:fluvie_server/src/api/jobs/job_store.dart';
import 'package:fluvie_server/src/api/jobs/render_job.dart';
import 'package:fluvie_server/src/api/storage/stored_object.dart';

/// A [JobStore] that writes one JSON file per job under a directory, so jobs and
/// their download links survive a restart.
///
/// Writes are atomic (a temp file is renamed into place). On boot, call
/// [reconcileInterruptedJobs] to flip any job left `running` (the process died
/// mid-render) to `failed`.
final class FileJobStore implements JobStore {
  /// Creates a store rooted at [dir] (created on demand).
  FileJobStore(this.dir);

  /// The directory holding `<id>.json` job files.
  final Directory dir;

  // Bumps per write so concurrent updates use distinct temp files.
  static int _tmpSeq = 0;

  @override
  Future<RenderJob> create(RenderJob job) => update(job);

  @override
  Future<RenderJob?> get(String id) async {
    final file = _fileFor(id);
    if (!file.existsSync()) return null;
    return _decode(jsonDecode(await file.readAsString()) as Map<String, Object?>);
  }

  @override
  Future<RenderJob> update(RenderJob job) async {
    await dir.create(recursive: true);
    // A unique temp name per write: concurrent updates of the same job (rapid
    // progress ticks) must not both rename the same temp file, which raced and
    // threw PathNotFoundException on the second rename.
    final temp = File('${_fileFor(job.id).path}.${_tmpSeq++}.tmp');
    await temp.writeAsString(jsonEncode(_encode(job)));
    await temp.rename(_fileFor(job.id).path);
    return job;
  }

  @override
  Stream<RenderJob> expiredBefore(DateTime cutoff) async* {
    for (final job in await _all()) {
      if (!job.expiresAt.isAfter(cutoff)) yield job;
    }
  }

  @override
  Future<void> delete(String id) async {
    final file = _fileFor(id);
    if (file.existsSync()) await file.delete();
  }

  /// Flips every job left in [JobStatus.running] (a render the previous process
  /// never finished) to [JobStatus.failed].
  Future<void> reconcileInterruptedJobs() async {
    for (final job in await _all()) {
      if (job.status == JobStatus.running) {
        await update(job.copyWith(status: JobStatus.failed, error: 'Server restarted mid-render'));
      }
    }
  }

  Future<List<RenderJob>> _all() async {
    if (!dir.existsSync()) return const [];
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'));
    return [
      for (final file in files)
        _decode(jsonDecode(await file.readAsString()) as Map<String, Object?>),
    ];
  }

  File _fileFor(String id) => File('${dir.path}/$id.json');

  Map<String, Object?> _encode(RenderJob job) => {
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

  RenderJob _decode(Map<String, Object?> json) {
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
}
