import 'package:fluvie/fluvie.dart' show Video;
import 'package:slides/decks/builds_deck.dart';
import 'package:slides/decks/full_talk_deck.dart';
import 'package:slides/decks/media_deck.dart';
import 'package:slides/decks/notes_deck.dart';
import 'package:slides/decks/video_deck.dart';
import 'package:slides/decks/welcome_deck.dart';
import 'package:slides/decks/what_is_fluvie_deck.dart';

/// One bundled presentation: a stable [id] (the speaker window resolves the
/// deck by it), what the picker shows, and the deck itself.
final class DeckEntry {
  /// Creates the entry.
  const DeckEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.build,
  });

  /// The stable identifier the speaker route resolves.
  final String id;

  /// The picker line.
  final String title;

  /// What the deck teaches.
  final String subtitle;

  /// Builds a fresh instance of the deck.
  final Video Function() build;
}

/// The bundled tutorial decks, simplest first — each one presents, and each
/// one teaches the feature it uses.
const List<DeckEntry> bundledDecks = [
  DeckEntry(
    id: 'welcome',
    title: 'Plain slides',
    subtitle: 'One scene is one slide',
    build: welcomeDeck,
  ),
  DeckEntry(
    id: 'builds',
    title: 'Builds with Stop',
    subtitle: 'Reveal content step by step',
    build: buildsDeck,
  ),
  DeckEntry(
    id: 'notes',
    title: 'Speaker notes',
    subtitle: 'Scene defaults and per-step overrides',
    build: notesDeck,
  ),
  DeckEntry(
    id: 'media',
    title: 'Media-heavy slides',
    subtitle: 'Charts, code, and live elements',
    build: mediaDeck,
  ),
  DeckEntry(
    id: 'video',
    title: 'Embedded video',
    subtitle: 'Real players with sound, on the web',
    build: videoDeck,
  ),
  DeckEntry(
    id: 'what-is-fluvie',
    title: 'What is fluvie',
    subtitle: 'Fourteen slides, notes on every one',
    build: whatIsFluvieDeck,
  ),
  DeckEntry(
    id: 'talk',
    title: 'The full talk',
    subtitle: 'Everything together, end to end',
    build: fullTalkDeck,
  ),
];

/// The bundled deck with [id], or `null` when there is none.
DeckEntry? deckById(String id) {
  for (final deck in bundledDecks) {
    if (deck.id == id) return deck;
  }
  return null;
}
