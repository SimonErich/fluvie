import 'package:flutter/widgets.dart' show immutable;

/// Where the submit flow is.
enum SubmitStatus {
  /// Filling in the form.
  editing,

  /// Waiting on the server render.
  submitting,

  /// The render finished and a download URL is available.
  done,

  /// The submit failed.
  failed,
}

/// The submit screen state: the promo inputs, the server target, and the job
/// lifecycle.
@immutable
class SubmitState {
  /// Creates a submit state.
  const SubmitState({
    required this.headline,
    required this.tagline,
    required this.accentHex,
    required this.serverUrl,
    required this.apiToken,
    this.status = SubmitStatus.editing,
    this.progress = 0,
    this.downloadUrl,
    this.error,
  });

  /// The promo headline.
  final String headline;

  /// The promo tagline.
  final String tagline;

  /// The accent color as a `#RRGGBB` hex string.
  final String accentHex;

  /// The render server base URL.
  final String serverUrl;

  /// The optional API token (kept in memory only).
  final String apiToken;

  /// The lifecycle status.
  final SubmitStatus status;

  /// Render progress 0..1 while submitting.
  final double progress;

  /// The finished video's download URL, when done.
  final Uri? downloadUrl;

  /// A failure message, when failed.
  final String? error;

  /// Whether a render is in flight.
  bool get isSubmitting => status == SubmitStatus.submitting;

  /// Returns a copy with the given fields replaced.
  SubmitState copyWith({
    String? headline,
    String? tagline,
    String? accentHex,
    String? serverUrl,
    String? apiToken,
    SubmitStatus? status,
    double? progress,
    Uri? downloadUrl,
    String? error,
    bool clearError = false,
    bool clearUrl = false,
  }) => SubmitState(
    headline: headline ?? this.headline,
    tagline: tagline ?? this.tagline,
    accentHex: accentHex ?? this.accentHex,
    serverUrl: serverUrl ?? this.serverUrl,
    apiToken: apiToken ?? this.apiToken,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    downloadUrl: clearUrl ? null : (downloadUrl ?? this.downloadUrl),
    error: clearError ? null : (error ?? this.error),
  );
}
