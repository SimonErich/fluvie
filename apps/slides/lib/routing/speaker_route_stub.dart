/// Non-web platforms have no URL to carry the speaker route.
bool isSpeakerRoute() => false;

/// Non-web platforms have no handoff store; the speaker window cannot
/// resolve a deck here.
void storeSpeakerDeck({required String kind, required String payload}) {}

/// Non-web platforms have no handoff store.
({String kind, String payload})? readSpeakerDeck() => null;
