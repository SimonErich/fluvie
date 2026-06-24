import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie_example/playground/ai_author_backend.dart';
import 'package:fluvie_example/playground/playground_code_editor.dart';
import 'package:fluvie_example/playground/playground_view_model.dart';

/// Where the AI Assistant is in its flow.
enum AiAssistantPhase {
  /// Showing the prompt field, waiting for a first request.
  idle,

  /// The first generation is running; the panel shows a full loading state.
  generating,

  /// Code has been generated; the panel shows the editor (and the video renders).
  ready,
}

/// What the AI Assistant panel binds to: its [phase], whether an edit is in
/// flight ([editing]), and a [message] for errors.
final class AiAssistantState {
  /// Creates a snapshot; the initial state is idle and error-free.
  const AiAssistantState({
    this.phase = AiAssistantPhase.idle,
    this.editing = false,
    this.message = '',
  });

  /// The current flow phase.
  final AiAssistantPhase phase;

  /// True while an edit re-generates over existing code; the editor stays
  /// visible behind a spinner overlay rather than swapping to a loading screen.
  final bool editing;

  /// A failure message to show inline, or the empty string.
  final String message;
}

/// Drives the AI Assistant: turn a prompt into a `Video build()`, drop it into
/// the shared editor ([playgroundCodeControllerProvider]), and auto-render it
/// through the [PlaygroundViewModel].
///
/// The generator lives behind [aiAuthorBackendProvider] (a local stub today,
/// overridden with a fake in tests), so this never touches the network directly.
/// Late callbacks are dropped after dispose via `ref.mounted`, and a superseded
/// request never writes its result back (sequence token).
final class AiAssistantViewModel extends Notifier<AiAssistantState> {
  int _seq = 0;

  @override
  AiAssistantState build() => const AiAssistantState();

  /// Generates a fresh video from [prompt]. Empty prompts are rejected with a
  /// hint instead of calling the backend.
  Future<void> generate(String prompt) async {
    if (prompt.trim().isEmpty) {
      state = const AiAssistantState(message: 'Describe the video you want first.');
      return;
    }
    await _run(prompt, currentCode: null);
  }

  /// Edits the current editor code with [prompt], keeping the editor on screen
  /// behind a spinner. A no-op for an empty prompt.
  Future<void> editWith(String prompt) async {
    if (prompt.trim().isEmpty) return;
    final code = ref.read(playgroundCodeControllerProvider).fullText;
    await _run(prompt, currentCode: code);
  }

  Future<void> _run(String prompt, {required String? currentCode}) async {
    final seq = ++_seq;
    final isEdit = currentCode != null;
    state = isEdit
        ? const AiAssistantState(phase: AiAssistantPhase.ready, editing: true)
        : const AiAssistantState(phase: AiAssistantPhase.generating);
    final backend = ref.read(aiAuthorBackendProvider);
    try {
      final result = await backend.author(prompt, currentCode: currentCode);
      if (!ref.mounted || seq != _seq) return;
      ref.read(playgroundCodeControllerProvider).fullText = result.code;
      state = const AiAssistantState(phase: AiAssistantPhase.ready);
      // Auto-render the freshly generated code; the centre stage picks up the
      // resulting video URL from the PlaygroundViewModel.
      unawaited(ref.read(playgroundViewModelProvider.notifier).render(result.code));
    } on AiAuthorException catch (error) {
      if (!ref.mounted || seq != _seq) return;
      // An expected, explainable failure (the free quota is spent, AI is off on
      // this server, or the prompt could not be authored): show it as-is.
      state = AiAssistantState(
        phase: isEdit ? AiAssistantPhase.ready : AiAssistantPhase.idle,
        message: error.message,
      );
    } on Object catch (error) {
      if (!ref.mounted || seq != _seq) return;
      // Fall back to the prompt on a first generation, or keep the editor on an
      // edit, and report the failure either way.
      state = AiAssistantState(
        phase: isEdit ? AiAssistantPhase.ready : AiAssistantPhase.idle,
        message: 'Generation failed: $error',
      );
    }
  }
}

/// The AI Assistant view model and its state.
final aiAssistantViewModelProvider = NotifierProvider<AiAssistantViewModel, AiAssistantState>(
  AiAssistantViewModel.new,
);
