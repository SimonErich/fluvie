import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitten_kit/kitten_kit.dart';

import 'package:mobile_purrfect/compose/compose_state.dart';
import 'package:mobile_purrfect/compose/compose_view_model.dart';

/// The compose screen: name the cat, optionally add a photo, render on-device.
class ComposeScreen extends ConsumerStatefulWidget {
  /// Creates the compose screen.
  const ComposeScreen({super.key});

  @override
  ConsumerState<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends ConsumerState<ComposeScreen> {
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: ref.read(composeViewModelProvider).catName,
    );
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(composeViewModelProvider);
    final vm = ref.read(composeViewModelProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Kitten Mitten')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Center(child: KittenFace(size: 116, fur: KittenColors.mitten)),
          const SizedBox(height: 12),
          const Text(
            'Cat birthday card',
            style: KittenType.display,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            'Make a video card for your cat, rendered right on your phone.',
            style: KittenType.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextField(
            key: const ValueKey('cat-name'),
            controller: _name,
            decoration: const InputDecoration(labelText: "Cat's name"),
            onChanged: vm.setCatName,
          ),
          const SizedBox(height: 14),
          _PhotoTile(
            hasPhoto: state.hasPhoto,
            onTap: state.isRendering ? null : vm.pickPhoto,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            key: const ValueKey('render-button'),
            onPressed: state.canRender ? vm.render : null,
            icon: const Icon(Icons.cake_outlined),
            label: Text(
              state.isRendering ? 'Rendering on device…' : 'Make the card',
            ),
          ),
          const SizedBox(height: 16),
          _StatusArea(state: state, onShare: vm.share, onReset: vm.reset),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.hasPhoto, required this.onTap});

  final bool hasPhoto;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: KittenColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasPhoto ? KittenColors.ok : KittenColors.line,
          ),
        ),
        child: Row(
          children: [
            Icon(
              hasPhoto ? Icons.check_circle : Icons.add_a_photo_outlined,
              color: hasPhoto ? KittenColors.ok : KittenColors.whisker,
            ),
            const SizedBox(width: 12),
            Text(
              hasPhoto ? 'Photo added' : 'Add a photo (optional)',
              style: KittenType.body,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusArea extends StatelessWidget {
  const _StatusArea({
    required this.state,
    required this.onShare,
    required this.onReset,
  });

  final ComposeState state;
  final VoidCallback onShare;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case ComposeStatus.editing:
        return const SizedBox.shrink();
      case ComposeStatus.rendering:
        return Column(
          children: [
            LinearProgressIndicator(
              value: state.progress == 0 ? null : state.progress,
            ),
            const SizedBox(height: 8),
            const Text(
              'Encoding with your phone, nothing leaves the device.',
              style: KittenType.caption,
            ),
          ],
        );
      case ComposeStatus.done:
        return Column(
          children: [
            const KittenBanner(
              color: KittenColors.ok,
              icon: Icons.check_circle,
              child: Text('Your card is ready!', style: KittenType.body),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onShare,
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Share'),
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: onReset,
                  child: const Text('Make another'),
                ),
              ],
            ),
          ],
        );
      case ComposeStatus.failed:
        return KittenBanner(
          color: KittenColors.err,
          icon: Icons.error_outline,
          child: Text(state.error ?? 'Render failed.', style: KittenType.body),
        );
    }
  }
}

// The status banner is shared from kitten_kit (KittenBanner).
