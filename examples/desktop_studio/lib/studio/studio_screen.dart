import 'package:desktop_studio/render/templates.dart';
import 'package:desktop_studio/studio/studio_state.dart';
import 'package:desktop_studio/studio/studio_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitten_kit/kitten_kit.dart';

/// The studio screen: pick a kitten template, then render it to a local MP4.
class StudioScreen extends ConsumerWidget {
  /// Creates the studio screen.
  const StudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studioViewModelProvider);
    final vm = ref.read(studioViewModelProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Kitten Mitten · Studio')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text('Pick a template', style: KittenType.title),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final template in studioTemplates)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _TemplateCard(
                          template: template,
                          selected: template.key == state.selectedKey,
                          onTap: () => vm.selectTemplate(template.key),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                value: state.draft,
                onChanged: state.isRendering ? null : (_) => vm.toggleDraft(),
                title: const Text(
                  'Draft render (first 30 frames, faster)',
                  style: KittenType.body,
                ),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                key: const ValueKey('render-button'),
                onPressed: state.isRendering ? null : vm.render,
                icon: const Icon(Icons.movie_creation_outlined),
                label: Text(
                  state.isRendering ? 'Rendering via the CLI…' : 'Render to MP4',
                ),
              ),
              const SizedBox(height: 16),
              _StatusArea(state: state),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.selected,
    required this.onTap,
  });

  final StudioTemplate template;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: KittenColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? KittenColors.mitten : KittenColors.line,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: Column(
          children: [
            KittenFace(size: 84, fur: template.fur),
            const SizedBox(height: 8),
            Text(template.label, style: KittenType.body),
          ],
        ),
      ),
    );
  }
}

class _StatusArea extends StatelessWidget {
  const _StatusArea({required this.state});

  final StudioState state;

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case StudioStatus.idle:
        return const SizedBox.shrink();
      case StudioStatus.rendering:
        return const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text(
              'Capturing and encoding with the CLI…',
              style: KittenType.caption,
            ),
          ],
        );
      case StudioStatus.done:
        final result = state.result!;
        return KittenBanner(
          color: KittenColors.ok,
          icon: Icons.check_circle,
          child: Text(
            'Saved ${result.outputPath} (${(result.bytes / 1024).round()} KB)',
            style: KittenType.body,
          ),
        );
      case StudioStatus.failed:
        return KittenBanner(
          color: KittenColors.err,
          icon: Icons.error_outline,
          child: Text(state.error ?? 'Render failed.', style: KittenType.body),
        );
    }
  }
}

// The status banner is shared from kitten_kit (KittenBanner).
