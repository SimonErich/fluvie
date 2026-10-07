import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:slides/loader/autosave_record.dart';
import 'package:slides/loader/recent_deck.dart';

/// The recents list: the thing a returning user comes here for.
///
/// An entry is tappable only when it carries a path. Web entries have no
/// path, so they render as plain history instead of a dead button.
final class StartRecents extends StatelessWidget {
  /// Lists [recents], newest first, with timestamps read against [now].
  const StartRecents({
    required this.recents,
    required this.now,
    required this.onOpenRecent,
    required this.onOpenDeck,
    super.key,
  });

  /// The remembered decks, most recent first.
  final List<RecentDeck> recents;

  /// The clock the "opened" stamps read against.
  final DateTime now;

  /// Reopens an entry (only called for entries with a path).
  final void Function(RecentDeck deck) onOpenRecent;

  /// Opens the system picker for a deck the list does not hold.
  final VoidCallback onOpenDeck;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const OiLabel.h4('Recent decks'),
            const Spacer(),
            if (recents.isNotEmpty)
              OiButton.ghost(
                label: 'Open a deck',
                icon: OiIcons.folderOpen,
                size: OiButtonSize.small,
                onTap: onOpenDeck,
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (recents.isEmpty)
          OiCard.flat(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: const OiEmptyState(
              icon: OiIcons.folderClock,
              title: 'No recent decks',
              description:
                  'Save a deck and it shows up here. Use New deck to begin, or open a '
                  '.fluvie file you already have.',
            ),
          )
        else
          for (final deck in recents)
            if (deck.path case final String path)
              OiListTile(
                leading: _DeckGlyph(name: deck.name),
                title: deck.name,
                subtitle: 'Opened ${relativeTimeLabel(deck.lastOpened, now)}  ·  $path',
                onTap: () => onOpenRecent(deck),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    _DeckGlyph(name: deck.name, dimmed: true),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OiLabel.small(
                            deck.name,
                            color: colors.textSubtle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          OiLabel.tiny(
                            'Opened ${relativeTimeLabel(deck.lastOpened, now)}. '
                            'The browser cannot reopen a deck by path.',
                            color: colors.textMuted,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ],
    );
  }
}

/// A painted stand-in for a deck thumbnail: the deck's initial on a slide
/// shaped chip, in the same palette the hero and the samples use.
final class _DeckGlyph extends StatelessWidget {
  const _DeckGlyph({required this.name, this.dimmed = false});

  final String name;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final initial = name.isEmpty ? '·' : name.substring(0, 1).toUpperCase();
    return SizedBox(
      width: 44,
      height: 26,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: context.radius.sm,
          border: Border.all(color: colors.borderSubtle),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1B2838), Color(0xFF14141C)],
          ),
        ),
        child: Center(
          child: OiLabel.tiny(initial, color: dimmed ? colors.textMuted : colors.textSubtle),
        ),
      ),
    );
  }
}
