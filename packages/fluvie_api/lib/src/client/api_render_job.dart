import 'package:meta/meta.dart';

/// A downloadable artifact (the video or its poster) in a [RenderJobView].
@immutable
final class FileLink {
  /// Creates a file link.
  const FileLink({required this.downloadUrl, this.bytes, this.contentType, this.expiresAt});

  /// Parses a link from [json].
  factory FileLink.fromJson(Map<String, Object?> json) => FileLink(
    downloadUrl: Uri.parse(json['downloadUrl']! as String),
    bytes: json['bytes'] as int?,
    contentType: json['contentType'] as String?,
    expiresAt: _time(json['expiresAt'] as String?),
  );

  /// Where to download the file (a server URL; private files carry a token).
  final Uri downloadUrl;

  /// Size in bytes, when known.
  final int? bytes;

  /// MIME type, when known.
  final String? contentType;

  /// When a redirect/presigned URL expires, when applicable.
  final DateTime? expiresAt;

  /// The link as a JSON map.
  Map<String, Object?> toJson() => {
    'downloadUrl': downloadUrl.toString(),
    'bytes': ?bytes,
    'contentType': ?contentType,
    'expiresAt': ?expiresAt?.toUtc().toIso8601String(),
  };
}

/// A render job as seen by a client: status, progress, and download links.
///
/// The same shape the server serializes and the client parses, so the two never
/// drift.
@immutable
final class RenderJobView {
  /// Creates a job view.
  const RenderJobView({
    required this.id,
    required this.status,
    this.completed,
    this.total,
    this.error,
    this.video,
    this.poster,
    this.createdAt,
    this.expiresAt,
  });

  /// Parses a job view from [json].
  factory RenderJobView.fromJson(Map<String, Object?> json) {
    final progress = json['progress'] as Map<String, Object?>?;
    final video = json['video'] as Map<String, Object?>?;
    final poster = json['poster'] as Map<String, Object?>?;
    return RenderJobView(
      id: json['id']! as String,
      status: json['status']! as String,
      completed: progress?['completed'] as int?,
      total: progress?['total'] as int?,
      error: json['error'] as String?,
      video: video == null ? null : FileLink.fromJson(video),
      poster: poster == null ? null : FileLink.fromJson(poster),
      createdAt: _time(json['createdAt'] as String?),
      expiresAt: _time(json['expiresAt'] as String?),
    );
  }

  /// The job id.
  final String id;

  /// One of `queued`, `running`, `succeeded`, `failed`.
  final String status;

  /// Frames captured so far, while running.
  final int? completed;

  /// Total frames, while running.
  final int? total;

  /// The failure message when [status] is `failed`.
  final String? error;

  /// The video link, present once succeeded.
  final FileLink? video;

  /// The poster link, present once succeeded (when a poster was requested).
  final FileLink? poster;

  /// When the job was created.
  final DateTime? createdAt;

  /// When the job's files expire.
  final DateTime? expiresAt;

  /// Whether the render finished successfully.
  bool get isSucceeded => status == 'succeeded';

  /// Whether the render failed.
  bool get isFailed => status == 'failed';

  /// Whether the render is still queued or running.
  bool get isPending => status == 'queued' || status == 'running';

  /// Completion as a `0..1` fraction (`0` until a total is known).
  double get progress => (total == null || total! <= 0) ? 0 : (completed! / total!).clamp(0.0, 1.0);

  /// The job view as a JSON map.
  Map<String, Object?> toJson() => {
    'id': id,
    'status': status,
    'progress': ?(completed == null || total == null
        ? null
        : {'completed': completed, 'total': total}),
    'error': ?error,
    'video': ?video?.toJson(),
    'poster': ?poster?.toJson(),
    'createdAt': ?createdAt?.toUtc().toIso8601String(),
    'expiresAt': ?expiresAt?.toUtc().toIso8601String(),
  };
}

DateTime? _time(String? iso) => iso == null ? null : DateTime.parse(iso).toUtc();
