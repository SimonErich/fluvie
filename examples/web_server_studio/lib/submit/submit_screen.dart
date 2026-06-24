import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitten_kit/kitten_kit.dart';

import 'package:web_server_studio/submit/submit_state.dart';
import 'package:web_server_studio/submit/submit_view_model.dart';

const List<String> _accents = <String>[
  '#FF8FB1',
  '#F6A04D',
  '#6CC4E0',
  '#E5638C',
];

Color _hexColor(String hex) => Color(int.parse('FF${hex.substring(1)}', radix: 16));

/// The promo studio screen: a form whose promo is rendered on the server.
class SubmitScreen extends ConsumerStatefulWidget {
  /// Creates the submit screen.
  const SubmitScreen({super.key});

  @override
  ConsumerState<SubmitScreen> createState() => _SubmitScreenState();
}

class _SubmitScreenState extends ConsumerState<SubmitScreen> {
  late final Map<String, TextEditingController> _fields;

  @override
  void initState() {
    super.initState();
    final state = ref.read(submitViewModelProvider);
    _fields = {
      'headline': TextEditingController(text: state.headline),
      'tagline': TextEditingController(text: state.tagline),
      'server': TextEditingController(text: state.serverUrl),
      'token': TextEditingController(text: state.apiToken),
    };
    // The headless e2e builds with --dart-define=FLUVIE_E2E=true and waits for
    // the render marker, so it does not have to click the Flutter canvas.
    if (const bool.fromEnvironment('FLUVIE_E2E')) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(submitViewModelProvider.notifier).submit(),
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(submitViewModelProvider);
    final vm = ref.read(submitViewModelProvider.notifier);
    ref.listen(submitViewModelProvider, (previous, next) {
      if (next.status == SubmitStatus.done && previous?.status != SubmitStatus.done) {
        // The headless end-to-end harness reads this marker from the console.
        // ignore: avoid_print
        print('FLUVIE_E2E_RESULT ok url=${next.downloadUrl}');
      } else if (next.status == SubmitStatus.failed && previous?.status != SubmitStatus.failed) {
        // Surface the failure so the harness fails fast with the reason.
        // ignore: avoid_print
        print('FLUVIE_E2E_ERROR ${next.error}');
      }
    });
    return Scaffold(
      appBar: AppBar(title: const Text('Kitten Mitten · Promo studio')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _field('headline', 'Headline', vm.setHeadline),
              const SizedBox(height: 12),
              _field('tagline', 'Tagline', vm.setTagline),
              const SizedBox(height: 16),
              _AccentPicker(selected: state.accentHex, onPick: vm.setAccent),
              const SizedBox(height: 16),
              _field('server', 'Render server URL', vm.setServerUrl),
              const SizedBox(height: 12),
              _field(
                'token',
                'API token (optional)',
                vm.setApiToken,
                obscure: true,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: state.isSubmitting ? null : vm.submit,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: Text(
                  state.isSubmitting ? 'Rendering on the server…' : 'Render on server',
                ),
              ),
              const SizedBox(height: 14),
              _StatusArea(state: state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    String key,
    String label,
    ValueChanged<String> onChanged, {
    bool obscure = false,
  }) {
    return TextField(
      controller: _fields[key],
      obscureText: obscure,
      decoration: InputDecoration(labelText: label),
      onChanged: onChanged,
    );
  }
}

class _AccentPicker extends StatelessWidget {
  const _AccentPicker({required this.selected, required this.onPick});

  final String selected;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Accent', style: KittenType.caption),
        const SizedBox(width: 12),
        for (final hex in _accents)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => onPick(hex),
              child: CircleAvatar(
                radius: 15,
                backgroundColor: _hexColor(hex),
                child: hex == selected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

class _StatusArea extends StatelessWidget {
  const _StatusArea({required this.state});

  final SubmitState state;

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case SubmitStatus.editing:
        return const SizedBox.shrink();
      case SubmitStatus.submitting:
        return Column(
          children: [
            LinearProgressIndicator(
              value: state.progress == 0 ? null : state.progress,
            ),
            const SizedBox(height: 8),
            const Text(
              'The server is capturing and encoding your promo.',
              style: KittenType.caption,
            ),
          ],
        );
      case SubmitStatus.done:
        return KittenBanner(
          color: KittenColors.ok,
          icon: Icons.check_circle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Done! Your video is ready:', style: KittenType.body),
              const SizedBox(height: 4),
              SelectableText('${state.downloadUrl}', style: KittenType.caption),
            ],
          ),
        );
      case SubmitStatus.failed:
        return KittenBanner(
          color: KittenColors.err,
          icon: Icons.error_outline,
          child: Text(state.error ?? 'Render failed.', style: KittenType.body),
        );
    }
  }
}

// The status banner is shared from kitten_kit (KittenBanner).
