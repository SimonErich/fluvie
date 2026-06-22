import 'package:meta/meta.dart';

/// Connection settings for an S3-compatible bucket (AWS, MinIO, R2, B2, Spaces).
@immutable
final class S3Config {
  /// Creates the S3 settings.
  const S3Config({
    required this.endpoint,
    required this.region,
    required this.bucket,
    required this.accessKey,
    required this.secretKey,
    required this.useSsl,
    required this.pathStyle,
    this.publicBaseUrl,
  });

  /// The host of the S3 endpoint, e.g. `nyc3.digitaloceanspaces.com`.
  final String endpoint;

  /// The region, e.g. `us-east-1`.
  final String region;

  /// The bucket every object lives in.
  final String bucket;

  /// The access key id.
  final String accessKey;

  /// The secret access key (never logged).
  final String secretKey;

  /// Whether to use HTTPS.
  final bool useSsl;

  /// Whether to use path-style URLs (needed for MinIO and Backblaze B2).
  final bool pathStyle;

  /// Base URL for public objects (a CDN/bucket URL), or `null` to stream them.
  final Uri? publicBaseUrl;
}
