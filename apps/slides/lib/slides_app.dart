import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart' show Video;
import 'package:fluvie_presenter/fluvie_presenter.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:slides/deck/deck_registry.dart';
import 'package:slides/loader/open_fluvie_file.dart';
import 'package:slides/routing/speaker_route.dart';

/// The Fluvie slides shell: pick a bundled tutorial deck or open a local
/// `.fluvie` file, then present it with `FluvieSlides`.
///
/// All presentation logic lives in `package:fluvie_presenter`; this app only
/// decides what to present (and, on the web, hands the choice to the
/// speaker popup through local storage).
final class SlidesApp extends StatefulWidget {
  /// Creates the shell.
  const SlidesApp({this.openFile = openFluvieFile, super.key});

  /// How "Open a .fluvie file" obtains one; tests inject a fake picker.
  final Future<LoadedDeck?> Function() openFile;

  @override
  State<SlidesApp> createState() => _SlidesAppState();
}

final class _SlidesAppState extends State<SlidesApp> {
  Video? _presenting;
  String? _loadError;

  void _presentBundled(DeckEntry deck) {
    storeSpeakerDeck(kind: 'bundled', payload: deck.id);
    setState(() {
      _presenting = deck.build();
      _loadError = null;
    });
  }

  Future<void> _presentFile() async {
    final loaded = await widget.openFile();
    if (loaded == null || !mounted) return;
    _presentLoaded(loaded);
  }

  void _presentLoaded(LoadedDeck loaded) {
    if (loaded.video == null) {
      setState(() => _loadError = '${loaded.name}: ${loaded.error}');
      return;
    }
    storeSpeakerDeck(kind: 'file', payload: loaded.rawJson!);
    setState(() {
      _presenting = loaded.video;
      _loadError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final presenting = _presenting;
    return OiApp(
      title: 'fluvie slides',
      theme: OiThemeData.dark(),
      home: presenting != null
          ? _PresentingScreen(
              video: presenting,
              onClose: () => setState(() => _presenting = null),
            )
          : OiFileDropTarget(
              dropMessage: 'Drop a .fluvie file to present it',
              onInternalDrop: (_, _) {},
              // The barrel hides the drop payload type; inference names it.
              onExternalDrop: (files) {
                if (files.isEmpty) return;
                _presentLoaded(parseDroppedFluvie(files.first.name, files.first.bytes));
              },
              child: _DeckPicker(
                error: _loadError,
                onPickBundled: _presentBundled,
                onOpenFile: () => unawaited(_presentFile()),
              ),
            ),
    );
  }
}

final class _PresentingScreen extends StatelessWidget {
  const _PresentingScreen({required this.video, required this.onClose});

  final Video video;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => FluvieSlides(video, onClose: onClose);
}

final class _DeckPicker extends StatelessWidget {
  const _DeckPicker({required this.error, required this.onPickBundled, required this.onOpenFile});

  final String? error;
  final void Function(DeckEntry deck) onPickBundled;
  final VoidCallback onOpenFile;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ColoredBox(
      color: colors.background,
      child: Center(
        // Scrolls when the deck list outgrows a small window.
        child: SingleChildScrollView(
          child: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const OiLabel.h1('fluvie slides', textAlign: TextAlign.center),
                const SizedBox(height: 8),
                OiLabel.body(
                  'Pick a tutorial deck, open a .fluvie file, or drop one anywhere here.',
                  color: colors.textSubtle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                for (final deck in bundledDecks)
                  OiListTile(
                    title: deck.title,
                    subtitle: deck.subtitle,
                    onTap: () => onPickBundled(deck),
                  ),
                const SizedBox(height: 16),
                OiButton.primary(label: 'Open a .fluvie file', onTap: onOpenFile),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  OiLabel.small(error!, color: colors.error.base),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
