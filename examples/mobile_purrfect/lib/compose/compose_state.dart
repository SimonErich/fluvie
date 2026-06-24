import 'dart:typed_data';

import 'package:flutter/widgets.dart' show immutable;

/// Where the compose flow is.
enum ComposeStatus {
  /// Editing the card.
  editing,

  /// Rendering on the device.
  rendering,

  /// The card was rendered to a file.
  done,

  /// The render failed.
  failed,
}

/// The compose screen state: the card inputs and the render lifecycle.
@immutable
class ComposeState {
  /// Creates a compose state.
  const ComposeState({
    required this.catName,
    this.photoBytes,
    this.status = ComposeStatus.editing,
    this.progress = 0,
    this.outputPath,
    this.error,
  });

  /// The cat's name shown on the card.
  final String catName;

  /// The picked photo bytes, or null to use the default kitten art.
  final Uint8List? photoBytes;

  /// The lifecycle status.
  final ComposeStatus status;

  /// Render progress 0..1 while rendering.
  final double progress;

  /// The rendered file path, when done.
  final String? outputPath;

  /// A failure message, when failed.
  final String? error;

  /// Whether a photo has been picked.
  bool get hasPhoto => photoBytes != null;

  /// Whether a render is in flight.
  bool get isRendering => status == ComposeStatus.rendering;

  /// Whether the card can be rendered (a name is required).
  bool get canRender => catName.trim().isNotEmpty && !isRendering;

  /// Returns a copy with the given fields replaced.
  ComposeState copyWith({
    String? catName,
    Uint8List? photoBytes,
    ComposeStatus? status,
    double? progress,
    String? outputPath,
    String? error,
    bool clearError = false,
    bool clearOutput = false,
  }) => ComposeState(
    catName: catName ?? this.catName,
    photoBytes: photoBytes ?? this.photoBytes,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    outputPath: clearOutput ? null : (outputPath ?? this.outputPath),
    error: clearError ? null : (error ?? this.error),
  );
}
