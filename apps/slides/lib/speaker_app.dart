import 'package:flutter/widgets.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiLabel, OiThemeData;
import 'package:slides/deck/deck_registry.dart';
import 'package:slides/loader/open_fluvie_file.dart';
import 'package:slides/routing/speaker_route.dart';

/// The speaker window's shell: resolve the deck the main window recorded
/// (a bundled id or a `.fluvie` payload) and mount `FluvieSpeaker` on it.
///
/// The two windows then talk over the presenter's sync channel; this shell
/// only answers "which deck".
final class SpeakerApp extends StatelessWidget {
  /// Creates the speaker shell.
  const SpeakerApp({this.readDeck = readSpeakerDeck, super.key});

  /// How the shell resolves the handed-off deck; tests inject a fake store.
  final ({String kind, String payload})? Function() readDeck;

  @override
  Widget build(BuildContext context) {
    final stored = readDeck();
    Widget body;
    if (stored == null) {
      body = const _SpeakerMessage(
        'Nothing is being presented yet. Start the presentation in the main '
        'window, then press S there again.',
      );
    } else if (stored.kind == 'bundled') {
      final deck = deckById(stored.payload);
      body = deck == null
          ? _SpeakerMessage('Unknown deck "${stored.payload}".')
          : FluvieSpeaker(deck.build());
    } else {
      final loaded = parseFluvieJson('presented file', stored.payload);
      final video = loaded.video;
      body = video == null
          ? _SpeakerMessage('The presented file no longer parses: ${loaded.error}')
          : FluvieSpeaker(video);
    }
    return OiApp(title: 'fluvie speaker', theme: OiThemeData.dark(), home: body);
  }
}

final class _SpeakerMessage extends StatelessWidget {
  const _SpeakerMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(padding: const EdgeInsets.all(32), child: OiLabel.body(message)),
  );
}
