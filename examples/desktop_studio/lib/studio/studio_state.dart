import 'package:desktop_studio/render/render_service.dart';
import 'package:flutter/widgets.dart' show immutable;

/// Where a render is in its lifecycle.
enum StudioStatus {
  /// Idle, ready to render.
  idle,

  /// A render is running.
  rendering,

  /// The render finished and wrote a file.
  done,

  /// The render failed.
  failed,
}

/// The studio screen state: the chosen template, the draft toggle, and the
/// render lifecycle.
@immutable
class StudioState {
  /// Creates a studio state.
  const StudioState({
    required this.selectedKey,
    this.draft = false,
    this.status = StudioStatus.idle,
    this.result,
    this.error,
  });

  /// The selected template key.
  final String selectedKey;

  /// Whether to render a fast draft (fewer frames).
  final bool draft;

  /// The render lifecycle status.
  final StudioStatus status;

  /// The finished render, when done.
  final RenderResult? result;

  /// A failure message, when failed.
  final String? error;

  /// Whether a render is in flight.
  bool get isRendering => status == StudioStatus.rendering;

  /// Returns a copy with the given fields replaced.
  StudioState copyWith({
    String? selectedKey,
    bool? draft,
    StudioStatus? status,
    RenderResult? result,
    String? error,
    bool clearResult = false,
    bool clearError = false,
  }) => StudioState(
    selectedKey: selectedKey ?? this.selectedKey,
    draft: draft ?? this.draft,
    status: status ?? this.status,
    result: clearResult ? null : (result ?? this.result),
    error: clearError ? null : (error ?? this.error),
  );
}
