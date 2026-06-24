import 'package:flutter/widgets.dart' show Color, immutable;

/// Where the maker is in its lifecycle.
enum MakerStatus {
  /// Editing the meme text and accent.
  editing,

  /// Rendering in the browser.
  encoding,

  /// The MP4 was rendered and handed to the browser as a download.
  done,

  /// The render failed.
  failed,
}

/// The maker screen state: the meme inputs plus the render status.
@immutable
class MakerState {
  /// Creates a maker state.
  const MakerState({
    required this.topText,
    required this.bottomText,
    required this.accent,
    this.status = MakerStatus.editing,
    this.progress = 0,
    this.error,
  });

  /// The top caption.
  final String topText;

  /// The bottom caption.
  final String bottomText;

  /// The kitten accent color.
  final Color accent;

  /// The current lifecycle status.
  final MakerStatus status;

  /// Render progress in 0..1 while encoding.
  final double progress;

  /// A failure message, when [status] is [MakerStatus.failed].
  final String? error;

  /// Whether a render is in flight.
  bool get isEncoding => status == MakerStatus.encoding;

  /// Returns a copy with the given fields replaced.
  MakerState copyWith({
    String? topText,
    String? bottomText,
    Color? accent,
    MakerStatus? status,
    double? progress,
    String? error,
    bool clearError = false,
  }) => MakerState(
    topText: topText ?? this.topText,
    bottomText: bottomText ?? this.bottomText,
    accent: accent ?? this.accent,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    error: clearError ? null : (error ?? this.error),
  );
}
