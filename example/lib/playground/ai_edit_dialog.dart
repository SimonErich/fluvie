import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie_example/playground/ai_assistant_view_model.dart';
import 'package:fluvie_example/playground/playground_view_model.dart';
import 'package:fluvie_example/theme/fluvie_colors.dart';
import 'package:fluvie_example/theme/fluvie_shadows.dart';

/// The "edit with AI" button shown next to Render in the AI Assistant.
///
/// Opens a small overlay to describe a change, then applies it over the current
/// editor code (which the assistant rewrites and re-renders). The overlay is
/// rebuilt each time, so its field always opens empty.
final class AiEditButton extends ConsumerWidget {
  /// Creates the button.
  const AiEditButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(
      playgroundViewModelProvider.select((s) => s.validating || s.rendering),
    );
    final editing = ref.watch(aiAssistantViewModelProvider.select((s) => s.editing));
    final enabled = !busy && !editing;
    return Tooltip(
      message: 'Edit the current code with AI',
      child: OutlinedButton.icon(
        onPressed: enabled ? () => unawaited(_open(context, ref)) : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: FluvieColors.acc,
          side: const BorderSide(color: FluvieColors.acc),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FluvieRadii.button)),
        ),
        icon: const Icon(Icons.auto_awesome, size: 18),
        label: const Text('AI'),
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final prompt = await showDialog<String>(
      context: context,
      builder: (_) => const AiEditDialog(),
    );
    if (prompt == null || prompt.trim().isEmpty) return;
    unawaited(ref.read(aiAssistantViewModelProvider.notifier).editWith(prompt));
  }
}

/// The edit overlay: a prompt for a change, returning the text via the
/// navigator (or null on cancel).
final class AiEditDialog extends StatefulWidget {
  /// Creates the dialog.
  const AiEditDialog({super.key});

  @override
  State<AiEditDialog> createState() => _AiEditDialogState();
}

class _AiEditDialogState extends State<AiEditDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit with AI'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Describe the change. The assistant rewrites the current code and '
          're-renders.',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          autofocus: true,
          minLines: 2,
          maxLines: 5,
          decoration: InputDecoration(
            filled: true,
            hintText: 'e.g. make the background red and the title bigger',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onSubmitted: (_) => _apply(),
        ),
      ],
    ),
    actions: [
      TextButton(onPressed: Navigator.of(context).pop, child: const Text('Cancel')),
      FilledButton(onPressed: _apply, child: const Text('Apply')),
    ],
  );
}
