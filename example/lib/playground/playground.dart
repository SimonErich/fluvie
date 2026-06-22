import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie_example/inspector/render_launcher.dart';
import 'package:fluvie_example/playground/playground_code_editor.dart';
import 'package:fluvie_example/playground/playground_view_model.dart';

/// The reusable Playground editor: write a Fluvie `Video build()`, validate it
/// on Render, and render it on the server. The rendered video shows wherever the
/// host places it (in the demo, the centre stage, replacing the live preview).
///
/// The editor with its diagnostics summary sits on top; below it a Render button
/// (a "Validating ..." state while it checks, then the live render progress).
/// Drives the [PlaygroundViewModel]; the backend is injected through
/// [playgroundBackendProvider].
final class Playground extends ConsumerStatefulWidget {
  /// Creates the Playground.
  const Playground({super.key});

  @override
  ConsumerState<Playground> createState() => _PlaygroundState();
}

class _PlaygroundState extends ConsumerState<Playground> {
  final GlobalKey _editorKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playgroundViewModelProvider);
    final busy = state.validating || state.rendering;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: PlaygroundCodeEditor(key: _editorKey)),
          const SizedBox(height: 8),
          _RenderControls(
            // Always clickable when idle: a click re-validates the current code
            // and renders only if it is now error-free, so stale errors never
            // lock the button.
            onRender: busy ? null : _render,
            validating: state.validating,
            rendering: state.rendering,
            progress: state.progress,
          ),
          if (state.message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                state.message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }

  void _render() {
    final code = PlaygroundCodeEditor.codeOf(_editorKey);
    unawaited(ref.read(playgroundViewModelProvider.notifier).render(code));
  }
}

/// The Render button plus the live render progress beneath it.
final class _RenderControls extends StatelessWidget {
  const _RenderControls({
    required this.onRender,
    required this.validating,
    required this.rendering,
    required this.progress,
  });

  final VoidCallback? onRender;
  final bool validating;
  final bool rendering;
  final RenderProgress? progress;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FilledButton.icon(
        onPressed: onRender,
        icon: validating
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.smart_display_outlined),
        label: Text(validating ? 'Validating ...' : 'Render'),
      ),
      if (rendering)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _RenderProgressView(progress: progress),
        ),
    ],
  );
}

/// The live render progress: a bar plus an "N / M frames" readout. Before the
/// first frame lands (or once every frame is captured and ffmpeg encodes) the
/// bar holds rather than restarting (mirrors the inspector's render progress).
final class _RenderProgressView extends StatelessWidget {
  const _RenderProgressView({required this.progress});

  final RenderProgress? progress;

  @override
  Widget build(BuildContext context) {
    final progress = this.progress;
    final String label;
    final double? value;
    if (progress == null) {
      label = 'Starting ...';
      value = null;
    } else if (progress.isComplete) {
      label = 'Encoding ...';
      value = 1;
    } else {
      label =
          '${progress.completed} / ${progress.total} frames '
          '(${(progress.fraction * 100).round()}%)';
      value = progress.fraction;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LinearProgressIndicator(value: value),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
