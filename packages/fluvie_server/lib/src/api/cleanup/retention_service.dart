import 'package:meta/meta.dart';

/// What one retention sweep did (or would do, for a dry run).
@immutable
final class RetentionReport {
  /// Creates a report.
  const RetentionReport({
    required this.scanned,
    required this.deletedFiles,
    required this.deletedJobs,
    required this.freedBytes,
    required this.dryRun,
    required this.startedAt,
    required this.finishedAt,
  });

  /// How many jobs and orphan objects were examined.
  final int scanned;

  /// How many files were deleted (or would be, when [dryRun]).
  final int deletedFiles;

  /// How many job records were deleted (or would be).
  final int deletedJobs;

  /// Total bytes reclaimed (or that would be).
  final int freedBytes;

  /// Whether this was a dry run (nothing deleted).
  final bool dryRun;

  /// When the sweep started (UTC).
  final DateTime startedAt;

  /// When the sweep finished (UTC).
  final DateTime finishedAt;

  /// The report as a JSON-encodable map.
  Map<String, Object?> toJson() => {
    'scanned': scanned,
    'deletedFiles': deletedFiles,
    'deletedJobs': deletedJobs,
    'freedBytes': freedBytes,
    'dryRun': dryRun,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'finishedAt': finishedAt.toUtc().toIso8601String(),
  };
}

/// Deletes expired render files and their job records.
// ignore: one_member_abstracts — the seam is the type; a fake backs it in tests.
abstract interface class RetentionService {
  /// Deletes everything whose expiry is at or before [now] (default: the
  /// current time). [dryRun] reports what would be deleted without deleting.
  Future<RetentionReport> sweep({DateTime? now, bool dryRun});
}
