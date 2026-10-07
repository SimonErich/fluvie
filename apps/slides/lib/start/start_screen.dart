import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:slides/deck/deck_registry.dart';
import 'package:slides/loader/recent_deck.dart';
import 'package:slides/start/samples_choice.dart';
import 'package:slides/start/samples_dialog.dart';
import 'package:slides/start/start_actions.dart';
import 'package:slides/start/start_hero.dart';
import 'package:slides/start/start_recents.dart';
import 'package:slides/start/start_templates.dart';
import 'package:slides/start/start_tips.dart';
import 'package:slides/templates/deck_templates.dart';
import 'package:slides/templates/template_gallery.dart';

part 'start_screen_layout.dart';

/// The studio open screen: brand, the two primary actions, the recents
/// list, the template strip, and the first-run tips card.
///
/// Sample decks live behind [showSamplesDialog]; they are not part of the
/// main flow. Nothing on this screen animates on a loop, so a test that
/// settles the tree here always returns.
final class StartScreen extends StatefulWidget {
  /// Creates the screen.
  const StartScreen({
    required this.error,
    required this.recents,
    required this.showTips,
    required this.onDismissTips,
    required this.onPickBundled,
    required this.onOpenFile,
    required this.onOpenRecent,
    required this.onNewDeck,
    required this.onNewFromTemplate,
    required this.onEditDemo,
    required this.onEditFile,
    this.now,
    super.key,
  });

  /// The last load error, or null.
  final String? error;

  /// The remembered decks, most recent first.
  final List<RecentDeck> recents;

  /// Whether to render the first-run tips card.
  final bool showTips;

  /// Puts the tips card away, and remembers that.
  final VoidCallback onDismissTips;

  /// Presents a bundled sample deck.
  final void Function(DeckEntry deck) onPickBundled;

  /// Opens the system picker to present a file.
  final VoidCallback onOpenFile;

  /// Reopens a recent deck (only called for entries with a path).
  final void Function(RecentDeck deck) onOpenRecent;

  /// Starts a blank deck in the editor.
  final VoidCallback onNewDeck;

  /// Starts a deck from a template (called with the pick).
  final void Function(DeckTemplate template) onNewFromTemplate;

  /// Opens the bundled demo spec in the editor.
  final VoidCallback onEditDemo;

  /// Opens the system picker to edit a file.
  final VoidCallback onEditFile;

  /// The clock recents timestamps read from; tests and goldens freeze it.
  final DateTime? now;

  @override
  State<StartScreen> createState() => _StartScreenState();
}

final class _StartScreenState extends State<StartScreen> {
  final ScrollController _rightScroll = ScrollController();
  final ScrollController _pageScroll = ScrollController();

  @override
  void dispose() {
    _rightScroll.dispose();
    _pageScroll.dispose();
    super.dispose();
  }

  Future<void> _openSamples() async {
    final choice = await showSamplesDialog(context);
    switch (choice) {
      case PresentSample(:final deck):
        widget.onPickBundled(deck);
      case EditDemoSample():
        widget.onEditDemo();
      case null:
        break;
    }
  }

  Future<void> _pickTemplate() async {
    final template = await showTemplateGallery(context);
    if (template != null) widget.onNewFromTemplate(template);
  }

  StartActions _actions({required bool compact}) => StartActions(
    compact: compact,
    onNewDeck: widget.onNewDeck,
    onOpenDeck: widget.onEditFile,
    onNewFromTemplate: () => unawaited(_pickTemplate()),
    onPresentFile: widget.onOpenFile,
    onOpenSamples: () => unawaited(_openSamples()),
  );

  /// The blocks the two layouts share, in the one order that keeps the
  /// primary buttons above the fold: the error, the tips, recents, then the
  /// templates.
  ///
  /// On a first run the tips card takes the empty list's place. Two "nothing
  /// here yet" panels stacked on one screen say nothing twice, and the
  /// templates then land above the fold where a new user can reach them.
  List<Widget> _body() {
    final firstRun = widget.showTips && widget.recents.isEmpty;
    return [
      if (widget.error case final String error) ...[
        OiBanner.error(message: error, dismissible: false),
        const SizedBox(height: 20),
      ],
      if (widget.showTips) ...[
        StartTips(
          onDismiss: widget.onDismissTips,
          onOpenSamples: () => unawaited(_openSamples()),
        ),
        const SizedBox(height: 28),
      ],
      if (!firstRun) ...[
        StartRecents(
          recents: widget.recents,
          now: widget.now ?? DateTime.now(),
          onOpenRecent: widget.onOpenRecent,
          onOpenDeck: widget.onEditFile,
        ),
        const SizedBox(height: 32),
      ],
      StartTemplates(
        onPick: widget.onNewFromTemplate,
        onBrowseAll: () => unawaited(_pickTemplate()),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.colors.background,
    child: context.isExpandedOrWider
        ? _WideLayout(
            scroll: _rightScroll,
            actions: _actions(compact: false),
            body: _body(),
          )
        : _CompactLayout(
            scroll: _pageScroll,
            actions: _actions(compact: true),
            body: _body(),
          ),
  );
}
