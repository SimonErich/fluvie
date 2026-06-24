import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie_example/inspector/render_launcher.dart';
import 'package:fluvie_example/playground/playground_code_editor.dart';
import 'package:fluvie_example/playground/playground_view_model.dart';
import 'package:fluvie_example/theme/widgets/gradient_button.dart';

/// The reusable Playground editor: write a Fluvie `Video build()`, validate it
/// on Render, and render it on the server. The rendered video shows wherever the
/// host places it (in the demo, the centre stage, replacing the live preview).
///
/// The editor with its diagnostics summary sits on top; below it a Render button
/// (a "Validating ..." state while it checks, then the live render progress).
/// Drives the [PlaygroundViewModel]; the backend is injected through
/// [playgroundBackendProvider]. An optional [renderTrailing] action sits next to
/// the Render button (the AI Assistant puts its "edit with AI" button there).
final class Playground extends ConsumerWidget {
  /// Creates the Playground, optionally with a [renderTrailing] action.
  const Playground({this.renderTrailing, super.key});

  /// An action shown immediately right of the Render button, or null for none.
  final Widget? renderTrailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playgroundViewModelProvider);
    final busy = state.validating || state.rendering;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Expanded(child: PlaygroundCodeEditor()),
          const SizedBox(height: 8),
          _RenderControls(
            // Always clickable when idle: a click re-validates the current code
            // and renders only if it is now error-free, so stale errors never
            // lock the button.
            onRender: busy ? null : () => _render(ref),
            validating: state.validating,
            rendering: state.rendering,
            progress: state.progress,
            trailing: renderTrailing,
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

  void _render(WidgetRef ref) {
    final code = ref.read(playgroundCodeControllerProvider).fullText;
    unawaited(ref.read(playgroundViewModelProvider.notifier).render(code));
  }
}

/// The Render button (with an optional [trailing] action) plus the live render
/// progress beneath it.
final class _RenderControls extends StatelessWidget {
  const _RenderControls({
    required this.onRender,
    required this.validating,
    required this.rendering,
    required this.progress,
    this.trailing,
  });

  final VoidCallback? onRender;
  final bool validating;
  final bool rendering;
  final RenderProgress? progress;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: GradientButton(
              onPressed: onRender,
              icon: validating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.smart_display_outlined),
              label: validating ? 'Validating ...' : 'Render',
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
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
