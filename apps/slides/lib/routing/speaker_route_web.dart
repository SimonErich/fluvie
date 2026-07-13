import 'package:web/web.dart' as web;

// coverage:ignore-file browser bindings the VM never loads this library

/// Whether this window was opened onto the speaker route (`#/speaker`).
bool isSpeakerRoute() => web.window.location.hash.startsWith('#/speaker');

/// Records what the main window is presenting, so the speaker popup (same
/// origin) can present the same deck: `kind` is `bundled` (payload = deck
/// id) or `file` (payload = the .fluvie JSON).
void storeSpeakerDeck({required String kind, required String payload}) {
  web.window.localStorage.setItem('fluvie_speaker_deck_kind', kind);
  web.window.localStorage.setItem('fluvie_speaker_deck_payload', payload);
}

/// The deck the main window recorded, or `null` when none was stored.
({String kind, String payload})? readSpeakerDeck() {
  final kind = web.window.localStorage.getItem('fluvie_speaker_deck_kind');
  final payload = web.window.localStorage.getItem('fluvie_speaker_deck_payload');
  if (kind == null || payload == null) return null;
  return (kind: kind, payload: payload);
}
