import 'package:cli_quickstart/preview/preview_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitten_kit/kitten_kit.dart';

/// The single quickstart screen: the kitten, the one render command, and the
/// current output status.
class PreviewScreen extends ConsumerWidget {
  /// Creates the preview screen.
  const PreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(previewViewModelProvider);
    final vm = ref.read(previewViewModelProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Kitten Mitten · CLI quickstart')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Center(child: KittenFace(size: 132)),
              const SizedBox(height: 16),
              const Text(
                'Whisker Daily Standup',
                style: KittenType.display,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Render this kitten intro to an MP4 with one command.',
                style: KittenType.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _CommandBox(command: state.command),
              const SizedBox(height: 20),
              _OutputStatus(state: state),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: state.checking ? null : vm.refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Check for output'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommandBox extends StatelessWidget {
  const _CommandBox({required this.command});

  final String command;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: SelectableText(
                command,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: KittenColors.ink,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Copy',
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () => Clipboard.setData(ClipboardData(text: command)),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutputStatus extends StatelessWidget {
  const _OutputStatus({required this.state});

  final PreviewState state;

  @override
  Widget build(BuildContext context) {
    if (state.checking) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 10),
          Text('Checking…', style: KittenType.caption),
        ],
      );
    }
    final output = state.output;
    final found = output != null;
    final label = found
        ? 'Rendered ${output.path} (${(output.bytes / 1024).round()} KB)'
        : 'No MP4 yet — run the command above, then check again.';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: (found ? KittenColors.ok : KittenColors.whisker).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            found ? Icons.check_circle : Icons.hourglass_empty,
            color: found ? KittenColors.ok : KittenColors.whisker,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: KittenType.body)),
        ],
      ),
    );
  }
}
