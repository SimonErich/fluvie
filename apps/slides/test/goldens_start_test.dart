@Tags(['golden'])
library;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart'
    show OiApp, OiButton, OiDialog, OiDialogShell, OiTheme, OiThemeData;
import 'package:slides/loader/recent_deck.dart';
import 'package:slides/start/samples_dialog.dart';
import 'package:slides/start/start_screen.dart';

/// The frozen clock every recents stamp reads against.
final DateTime _now = DateTime.utc(2026, 7, 26, 10);

RecentDeck _recent(String name, Duration ago, {String? path}) =>
    RecentDeck(name: name, path: path, lastOpened: _now.subtract(ago));

/// A returning user's shelf: a deck from minutes ago, one from this
/// morning, one from last week, and a browser entry with no path.
final List<RecentDeck> _recents = [
  _recent('design.fluvie', const Duration(minutes: 4), path: '/decks/design.fluvie'),
  _recent('q3-review.fluvie', const Duration(hours: 5), path: '/work/q3-review.fluvie'),
  _recent('keynote.fluvie', const Duration(days: 3), path: '/talks/keynote.fluvie'),
  _recent('web.fluvie', const Duration(days: 6)),
];

/// The screen on a fixed viewport: the layout reads its width from the
/// media query, so the golden pins the breakpoint, not the host window.
Widget _screen({
  required Size size,
  List<RecentDeck> recents = const [],
  bool showTips = false,
  bool samplesOpen = false,
}) => SizedBox.fromSize(
  size: size,
  child: OiApp(
    title: 'fluvie slides',
    theme: OiThemeData.dark(),
    debugShowCheckedModeBanner: false,
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Stack(
        children: [
          StartScreen(
            error: null,
            recents: recents,
            showTips: showTips,
            now: _now,
            onDismissTips: () {},
            onPickBundled: (_) {},
            onOpenFile: () {},
            onOpenRecent: (_) {},
            onNewDeck: () {},
            onNewFromTemplate: (_) {},
            onEditDemo: () {},
            onEditFile: () {},
          ),
          if (samplesOpen) const Positioned.fill(child: _SamplesOverlay()),
        ],
      ),
    ),
  ),
);

/// The samples dialog exactly as `showSamplesDialog` presents it: the same
/// barrier colour and the same [OiDialogShell] surface, composed in the tree
/// instead of pushed as a route, so the golden captures it in place.
final class _SamplesOverlay extends StatelessWidget {
  const _SamplesOverlay();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: OiTheme.of(context).colors.overlay,
    child: Center(
      child: OiDialogShell(
        minWidth: 320,
        maxWidth: 720,
        maxHeight: 720,
        semanticLabel: 'Samples and tutorials',
        child: OiDialog.form(
          label: 'Samples and tutorials',
          title: 'Samples and tutorials',
          content: SamplesGalleryList(onPick: (_) {}),
          actions: [OiButton.secondary(label: 'Close', onTap: () {})],
        ),
      ),
    ),
  );
}

Future<void> main() async {
  await goldenTest(
    'the first run leads with the actions, then the intro tips',
    fileName: 'start_first_run',
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        GoldenTestScenario(
          name: 'first run',
          child: _screen(size: const Size(1400, 900), showTips: true),
        ),
      ],
    ),
  );

  await goldenTest(
    'a returning user lands on their recent decks',
    fileName: 'start_returning',
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        GoldenTestScenario(
          name: 'returning',
          child: _screen(size: const Size(1400, 900), recents: _recents),
        ),
      ],
    ),
  );

  await goldenTest(
    'the samples dialog holds the tutorial decks',
    fileName: 'start_samples_open',
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        GoldenTestScenario(
          name: 'samples and tutorials',
          child: _screen(
            size: const Size(1400, 900),
            recents: _recents,
            samplesOpen: true,
          ),
        ),
      ],
    ),
  );

  await goldenTest(
    'the compact layout stacks the same blocks in one column',
    fileName: 'start_compact',
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        GoldenTestScenario(
          name: 'compact',
          child: _screen(size: const Size(720, 900), showTips: true),
        ),
      ],
    ),
  );
}
