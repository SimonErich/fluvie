import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie_example/inspector/render_launcher.dart';
import 'package:fluvie_example/playground/api_playground_backend.dart';
import 'package:fluvie_example/playground/playground_backend.dart';
import 'package:fluvie_server/client.dart';

/// What the Playground binds to: the editor's diagnostics, whether a validate
/// or render is in flight, the live render progress, the rendered video's URL,
/// and a human message for errors and blocked renders.
final class PlaygroundState {
  /// Creates a snapshot; the initial state is idle, error-free, and video-less.
  const PlaygroundState({
    this.diagnostics = const [],
    this.validating = false,
    this.rendering = false,
    this.progress,
    this.videoUrl,
    this.message = '',
  });

  /// The latest validation's diagnostics, in source order.
  final List<ApiCodeDiagnostic> diagnostics;

  /// True while a validation request is in flight.
  final bool validating;

  /// True while a render is in flight; the Render button disables itself.
  final bool rendering;

  /// Live capture progress while [rendering]; null before the first frame and
  /// once idle.
  final RenderProgress? progress;

  /// Where the most recent render can be downloaded and previewed, or null.
  final String? videoUrl;

  /// A message to show inline: a blocked-render reason or a backend error.
  final String message;

  /// True when any diagnostic is an error, so the snippet must not render.
  bool get hasErrors => diagnostics.any((d) => d.severity == ApiDiagnosticSeverity.error);

  /// Returns a copy with the given fields replaced.
  PlaygroundState copyWith({
    List<ApiCodeDiagnostic>? diagnostics,
    bool? validating,
    bool? rendering,
    RenderProgress? progress,
    String? videoUrl,
    String? message,
  }) => PlaygroundState(
    diagnostics: diagnostics ?? this.diagnostics,
    validating: validating ?? this.validating,
    rendering: rendering ?? this.rendering,
    progress: progress ?? this.progress,
    videoUrl: videoUrl ?? this.videoUrl,
    message: message ?? this.message,
  );
}

/// Drives the injected [PlaygroundBackend]: validate a `Video build()` snippet
/// for the editor, then render it server-side.
///
/// Validation never executes the snippet; rendering runs it in the server
/// sandbox. The backend lives behind [playgroundBackendProvider] (overridden
/// with a fake in tests), so this view model never touches the network
/// directly. Late callbacks are dropped after dispose via `ref.mounted`, and a
/// stale validation never overwrites a newer one (sequence token).
final class PlaygroundViewModel extends Notifier<PlaygroundState> {
  int _validateSeq = 0;

  @override
  PlaygroundState build() => const PlaygroundState();

  /// Validates [code] and stores its diagnostics; only the most recent request
  /// is allowed to write the result back.
  Future<void> validate(String code) async {
    final seq = ++_validateSeq;
    state = state.copyWith(validating: true);
    final backend = ref.read(playgroundBackendProvider);
    try {
      final result = await backend.validate(code);
      if (!ref.mounted || seq != _validateSeq) return;
      state = state.copyWith(diagnostics: result.diagnostics, validating: false);
    } on Object catch (error) {
      if (!ref.mounted || seq != _validateSeq) return;
      state = state.copyWith(validating: false, message: 'Validation failed: $error');
    }
  }

  /// Validates [code], then renders it when it is error-free.
  ///
  /// A no-op while a render runs. When validation reports an error the render is
  /// blocked with a message and the backend is never called.
  Future<void> render(String code) async {
    if (state.rendering) return;
    await validate(code);
    if (!ref.mounted) return;
    if (state.hasErrors) {
      state = state.copyWith(message: 'Fix the errors above before rendering.');
      return;
    }
    state = PlaygroundState(
      diagnostics: state.diagnostics,
      rendering: true,
      progress: const RenderProgress(completed: 0, total: 1),
    );
    final backend = ref.read(playgroundBackendProvider);
    try {
      final result = await backend.render(
        code,
        onProgress: (progress) {
          if (!ref.mounted || !state.rendering) return;
          state = state.copyWith(progress: progress);
        },
      );
      if (!ref.mounted) return;
      state = PlaygroundState(
        diagnostics: state.diagnostics,
        videoUrl: result.exitCode == 0 ? result.downloadUrl : null,
        message: result.exitCode == 0 ? '' : result.stderr,
      );
    } on Object catch (error) {
      if (!ref.mounted) return;
      state = PlaygroundState(diagnostics: state.diagnostics, message: 'Render failed: $error');
    }
  }
}

/// The Playground view model and its state.
final playgroundViewModelProvider = NotifierProvider<PlaygroundViewModel, PlaygroundState>(
  PlaygroundViewModel.new,
);

/// The Playground backend, built from the environment; overridden with a fake
/// in tests.
final playgroundBackendProvider = Provider<PlaygroundBackend>((_) => createPlaygroundBackend());
