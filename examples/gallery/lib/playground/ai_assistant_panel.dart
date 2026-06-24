import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie_example/playground/ai_assistant_view_model.dart';
import 'package:fluvie_example/playground/ai_edit_dialog.dart';
import 'package:fluvie_example/playground/playground.dart';
import 'package:fluvie_example/theme/fluvie_colors.dart';
import 'package:fluvie_example/theme/widgets/gradient_button.dart';
import 'package:fluvie_example/theme/widgets/gradient_text.dart';
import 'package:fluvie_example/theme/widgets/section_label.dart';

/// The right-pane AI Assistant: a prompt that turns a description into a
/// rendered video, then the generated code in the editor with an "edit with AI"
/// button.
///
/// Switches on [AiAssistantPhase]: a big prompt while idle, a loading state
/// while generating, and the [Playground] once code exists.
final class AiAssistantPanel extends ConsumerWidget {
  /// Creates the panel.
  const AiAssistantPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(aiAssistantViewModelProvider.select((s) => s.phase));
    return switch (phase) {
      AiAssistantPhase.idle => const _PromptInput(),
      AiAssistantPhase.generating => const _GeneratingView(),
      AiAssistantPhase.ready => const _ReadyView(),
    };
  }
}

/// The idle state: a large prompt field with a creative example and a Generate
/// button. Owns the prompt's text controller.
final class _PromptInput extends ConsumerStatefulWidget {
  const _PromptInput();

  @override
  ConsumerState<_PromptInput> createState() => _PromptInputState();
}

class _PromptInputState extends ConsumerState<_PromptInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _generate() =>
      unawaited(ref.read(aiAssistantViewModelProvider.notifier).generate(_controller.text));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final message = ref.watch(aiAssistantViewModelProvider.select((s) => s.message));
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: SectionLabel('AI Assistant')),
              const SizedBox(height: 16),
              Icon(Icons.auto_awesome, size: 40, color: scheme.primary),
              const SizedBox(height: 12),
              GradientText(
                'Generate a video with AI',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Describe what you want to see. The assistant writes the Fluvie '
                'code and renders it for you.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                minLines: 4,
                maxLines: 8,
                decoration: InputDecoration(
                  filled: true,
                  hintText:
                      'e.g. A punchy 4-second intro for Nova Coffee. Warm sunrise '
                      'gradient, the title pops in, then a tagline fades up: '
                      "'Brewed for the bold'.",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onSubmitted: (_) => _generate(),
              ),
              if (message.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.error),
                ),
              ],
              const SizedBox(height: 16),
              GradientButton(
                onPressed: _generate,
                icon: const Icon(Icons.auto_awesome),
                label: 'Generate video',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The first-generation loading state.
final class _GeneratingView extends StatelessWidget {
  const _GeneratingView();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: FluvieColors.acc2.withValues(alpha: 0.4),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const CircularProgressIndicator(),
        ),
        const SizedBox(height: 24),
        Text('Generating your video ...', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Writing the Fluvie code and rendering a preview.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    ),
  );
}

/// The ready state: the editor (with the AI edit button) under a spinner overlay
/// while an edit re-generates, with a banner for any edit failure.
final class _ReadyView extends ConsumerWidget {
  const _ReadyView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(aiAssistantViewModelProvider);
    return Column(
      children: [
        if (state.message.isNotEmpty) _MessageBanner(message: state.message),
        Expanded(
          child: Stack(
            children: [
              const Playground(renderTrailing: AiEditButton()),
              if (state.editing) const Positioned.fill(child: _EditingOverlay()),
            ],
          ),
        ),
      ],
    );
  }
}

/// An inline banner that surfaces an AI Assistant failure (a spent quota, AI off
/// on the server, an un-authorable prompt) over the editor.
final class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: scheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}

/// A dimming spinner shown over the editor while an edit re-generates.
final class _EditingOverlay extends StatelessWidget {
  const _EditingOverlay();

  @override
  Widget build(BuildContext context) => ClipRect(
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.35),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Updating ...', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    ),
  );
}
