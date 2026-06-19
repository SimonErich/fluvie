import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_example/inspector/generate_view_model.dart';

/// The "Generate with AI" panel: a prompt box that authors a [VideoSpec] from
/// natural language, then shows a summary and the validated spec JSON.
///
/// Provider and API keys come from the environment (`FLUVIE_AI_PROVIDER`,
/// `ANTHROPIC_API_KEY`, ...); a missing key surfaces as an inline error.
final class GeneratePanel extends ConsumerStatefulWidget {
  /// Creates the panel.
  const GeneratePanel({super.key});

  @override
  ConsumerState<GeneratePanel> createState() => _GeneratePanelState();
}

class _GeneratePanelState extends ConsumerState<GeneratePanel> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(generateViewModelProvider);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Describe the video',
              hintText: 'a 6s vertical title card, dark gradient, fade-in headline',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: state.busy
                ? null
                : () => unawaited(
                    ref.read(generateViewModelProvider.notifier).generate(_controller.text),
                  ),
            icon: state.busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(state.busy ? 'Generating…' : 'Generate'),
          ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                state.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (state.spec != null) Expanded(child: _SpecResult(spec: state.spec!)),
        ],
      ),
    );
  }
}

class _SpecResult extends StatelessWidget {
  const _SpecResult({required this.spec});

  final VideoSpec spec;

  @override
  Widget build(BuildContext context) {
    final summary =
        '${spec.scenes.length} scene(s) · ${spec.size.width}×${spec.size.height} · ${spec.fps} fps';
    final json = const JsonEncoder.withIndent('  ').convert(spec.toJson());
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(summary, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: const Color(0xFF14141C),
              child: SingleChildScrollView(
                child: SelectableText(
                  json,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Color(0xFFE6EDF3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
