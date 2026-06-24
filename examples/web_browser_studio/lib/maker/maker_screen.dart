import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitten_kit/kitten_kit.dart';

import 'package:web_browser_studio/maker/maker_state.dart';
import 'package:web_browser_studio/maker/maker_view_model.dart';

const List<Color> _accents = <Color>[
  KittenColors.mitten,
  KittenColors.tabby,
  KittenColors.sky,
  KittenColors.mittenDeep,
];

/// The meme maker screen: a live preview, the captions and accent, and a button
/// that renders the MP4 fully in the browser.
class MakerScreen extends ConsumerStatefulWidget {
  /// Creates the maker screen.
  const MakerScreen({super.key});

  @override
  ConsumerState<MakerScreen> createState() => _MakerScreenState();
}

class _MakerScreenState extends ConsumerState<MakerScreen> {
  late final TextEditingController _top;
  late final TextEditingController _bottom;

  @override
  void initState() {
    super.initState();
    final state = ref.read(makerViewModelProvider);
    _top = TextEditingController(text: state.topText);
    _bottom = TextEditingController(text: state.bottomText);
    // The headless e2e builds with --dart-define=FLUVIE_E2E=true and waits for
    // the render marker, so it does not have to click the Flutter canvas.
    if (const bool.fromEnvironment('FLUVIE_E2E')) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await ref.read(makerViewModelProvider.notifier).makeMp4();
        final result = ref.read(makerViewModelProvider);
        if (result.status == MakerStatus.failed) {
          // Surface the failure so the harness fails fast with the reason; the
          // success marker is logged from the download path.
          // ignore: avoid_print
          print('FLUVIE_E2E_ERROR ${result.error}');
        }
      });
    }
  }

  @override
  void dispose() {
    _top.dispose();
    _bottom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(makerViewModelProvider);
    final vm = ref.read(makerViewModelProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Kitten Mitten · Meme maker')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _MemePreview(state: state),
              const SizedBox(height: 18),
              TextField(
                controller: _top,
                decoration: const InputDecoration(labelText: 'Top text'),
                onChanged: vm.setTop,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bottom,
                decoration: const InputDecoration(labelText: 'Bottom text'),
                onChanged: vm.setBottom,
              ),
              const SizedBox(height: 16),
              _AccentPicker(selected: state.accent, onPick: vm.setAccent),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: state.isEncoding ? null : vm.makeMp4,
                icon: const Icon(Icons.movie_creation_outlined),
                label: Text(
                  state.isEncoding ? 'Rendering in your browser…' : 'Make MP4',
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
}

const TextStyle _memeText = TextStyle(
  color: Colors.white,
  fontSize: 22,
  fontWeight: FontWeight.w800,
);

class _MemePreview extends StatelessWidget {
  const _MemePreview({required this.state});

  final MakerState state;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF20141F), Color(0xFF3A1E3A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            KittenFace(size: 168, fur: state.accent),
            Positioned(
              top: 14,
              left: 12,
              right: 12,
              child: Text(
                state.topText.toUpperCase(),
                textAlign: TextAlign.center,
                style: _memeText,
              ),
            ),
            Positioned(
              bottom: 14,
              left: 12,
              right: 12,
              child: Text(
                state.bottomText.toUpperCase(),
                textAlign: TextAlign.center,
                style: _memeText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccentPicker extends StatelessWidget {
  const _AccentPicker({required this.selected, required this.onPick});

  final Color selected;
  final ValueChanged<Color> onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Accent', style: KittenType.caption),
        const SizedBox(width: 12),
        for (final color in _accents)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => onPick(color),
              child: CircleAvatar(
                radius: 15,
                backgroundColor: color,
                child: color == selected
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

  final MakerState state;

  @override
  Widget build(BuildContext context) {
    return switch (state.status) {
      MakerStatus.editing => const SizedBox.shrink(),
      MakerStatus.encoding => Column(
        children: [
          LinearProgressIndicator(
            value: state.progress == 0 ? null : state.progress,
          ),
          const SizedBox(height: 8),
          const Text(
            'ffmpeg.wasm runs entirely in your browser.',
            style: KittenType.caption,
          ),
        ],
      ),
      MakerStatus.done => const KittenBanner(
        color: KittenColors.ok,
        icon: Icons.check_circle,
        child: Text('Done! kitten_meme.mp4 downloaded.', style: KittenType.body),
      ),
      MakerStatus.failed => KittenBanner(
        color: KittenColors.err,
        icon: Icons.error_outline,
        child: Text(state.error ?? 'Render failed.', style: KittenType.body),
      ),
    };
  }
}

// The status banner is shared from kitten_kit (KittenBanner).
