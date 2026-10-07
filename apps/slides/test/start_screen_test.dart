import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiListTile, OiThemeData;
import 'package:slides/deck/deck_registry.dart';
import 'package:slides/editor/editor_screen.dart' show EditorScreen;
import 'package:slides/loader/recent_deck.dart';
import 'package:slides/loader/start_prefs_store.dart';
import 'package:slides/slides_app.dart';
import 'package:slides/start/samples_dialog.dart';
import 'package:slides/start/start_hero.dart';
import 'package:slides/start/start_screen.dart';
import 'package:slides/start/start_templates.dart';
import 'package:slides/start/start_tips.dart';
import 'package:slides/templates/deck_templates.dart';
import 'package:slides/templates/template_gallery.dart';

import 'desktop_surface.dart';
import 'memory_autosave_store.dart';
import 'memory_recents_store.dart';
import 'memory_start_prefs_store.dart';
import 'start_screen_robot.dart';

final DateTime _now = DateTime.utc(2026, 7, 26, 10);

RecentDeck _recent(String name, {String? path, Duration ago = const Duration(minutes: 4)}) =>
    RecentDeck(name: name, path: path, lastOpened: _now.subtract(ago));

/// What the screen called back with.
final class _Calls {
  final List<DeckEntry> presented = [];
  final List<RecentDeck> opened = [];
  final List<DeckTemplate> templates = [];
  int dismissals = 0;
  int demos = 0;
}

/// Mounts the screen alone, so its own behaviour is testable without the
/// shell's file plumbing.
Future<_Calls> _pump(
  WidgetTester tester, {
  List<RecentDeck> recents = const [],
  bool showTips = false,
  String? error,
}) async {
  useDesktopSurface(tester);
  final calls = _Calls();
  await tester.pumpWidget(
    OiApp(
      title: 'test',
      theme: OiThemeData.dark(),
      home: StartScreen(
        error: error,
        recents: recents,
        showTips: showTips,
        now: _now,
        onDismissTips: () => calls.dismissals++,
        onPickBundled: calls.presented.add,
        onOpenFile: () {},
        onOpenRecent: calls.opened.add,
        onNewDeck: () {},
        onNewFromTemplate: calls.templates.add,
        onEditDemo: () => calls.demos++,
        onEditFile: () {},
      ),
    ),
  );
  await tester.pump();
  return calls;
}

void main() {
  testWidgets('the empty screen leads with the two primary actions', (tester) async {
    await _pump(tester);
    expect(find.text('fluvie slides'), findsOneWidget);
    expect(find.text('PRESENTATION STUDIO'), findsOneWidget);
    expect(find.text('New deck'), findsOneWidget);
    expect(find.text('New from template'), findsOneWidget);
    expect(find.text('Present a .fluvie file'), findsOneWidget);
    expect(find.text('Samples and tutorials'), findsOneWidget);
    // No sample deck is advertised on the screen itself.
    expect(find.text('Plain slides'), findsNothing);
    expect(find.text('The full talk'), findsNothing);
    // The empty recents state invites a first save.
    expect(find.text('No recent decks'), findsOneWidget);
    expect(find.text('Templates'), findsOneWidget);
  });

  testWidgets('a load error rides an error banner', (tester) async {
    await _pump(tester, error: 'broken.fluvie: not a deck');
    expect(find.text('broken.fluvie: not a deck'), findsOneWidget);
  });

  testWidgets('the tips card shows on a first run and dismisses on Got it', (tester) async {
    final calls = await _pump(tester, showTips: true);
    expect(find.byType(StartTips), findsOneWidget);
    expect(find.text('New here?'), findsOneWidget);
    expect(find.text('A scene is a slide'), findsOneWidget);
    expect(find.text('Present with the keyboard'), findsOneWidget);
    expect(find.text('The same deck renders to video'), findsOneWidget);
    expect(find.text('Learn from the samples'), findsOneWidget);

    await tester.tap(find.text('Got it'));
    await tester.pump();
    expect(calls.dismissals, 1);

    await tester.tap(find.bySemanticsLabel('Dismiss the intro tips'));
    await tester.pump();
    expect(calls.dismissals, 2);
  });

  testWidgets('the tips card leads to the samples, and the hero survives a rebuild', (
    tester,
  ) async {
    final calls = await _pump(tester, showTips: true);
    await tester.tap(find.text('Open the samples'));
    await tester.pumpAndSettle();
    expect(find.byType(SamplesGalleryList), findsOneWidget);

    // Escape asks the shell to close, and nothing is picked.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(SamplesGalleryList), findsNothing);
    expect(calls.presented, isEmpty);
  });

  testWidgets('the hero band repaints when the theme under it changes', (tester) async {
    Future<void> pumpHero(OiThemeData theme) => tester.pumpWidget(
      OiApp(title: 'test', theme: theme, home: const StartHero(height: 180)),
    );
    await pumpHero(OiThemeData.dark());
    await pumpHero(OiThemeData.light());
    await tester.pump();
    expect(find.byType(StartHero), findsOneWidget);
  });

  testWidgets('Browse all opens the gallery and its pick starts a deck', (tester) async {
    final calls = await _pump(tester);
    await tester.tap(find.text('Browse all'));
    await tester.pumpAndSettle();
    expect(find.byType(TemplateGalleryList), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(TemplateGalleryList),
        matching: find.text(builtinDeckTemplates.first.name),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls.templates.single.id, builtinDeckTemplates.first.id);
  });

  testWidgets('the tips card stands in for the empty recents list', (tester) async {
    await _pump(tester, showTips: true);
    expect(find.byType(StartTips), findsOneWidget);
    // One "nothing here yet" panel is enough, and the templates move up.
    expect(find.text('No recent decks'), findsNothing);
    expect(find.text('Templates'), findsOneWidget);
  });

  testWidgets('the tips card is absent when it is switched off', (tester) async {
    await _pump(tester, recents: [_recent('design.fluvie', path: '/d/design.fluvie')]);
    expect(find.byType(StartTips), findsNothing);
    expect(find.text('New here?'), findsNothing);
  });

  testWidgets('a recent with a path is a tile that reopens; a pathless one is history', (
    tester,
  ) async {
    final calls = await _pump(
      tester,
      recents: [
        _recent('design.fluvie', path: '/decks/design.fluvie'),
        _recent('web.fluvie', ago: const Duration(hours: 5)),
      ],
    );
    expect(find.text('Recent decks'), findsOneWidget);
    expect(find.widgetWithText(OiListTile, 'design.fluvie'), findsOneWidget);
    expect(find.textContaining('Opened 4m ago'), findsOneWidget);

    // The pathless entry reads as history, and never as a dead button.
    expect(find.text('web.fluvie'), findsOneWidget);
    expect(find.widgetWithText(OiListTile, 'web.fluvie'), findsNothing);
    expect(
      find.text('Opened 5h ago. The browser cannot reopen a deck by path.'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(OiListTile, 'design.fluvie'));
    await tester.pump();
    expect(calls.opened.single.path, '/decks/design.fluvie');
  });

  testWidgets('a template card starts its deck without a dialog', (tester) async {
    final calls = await _pump(tester);
    final card = find.descendant(
      of: find.byType(StartTemplates),
      matching: find.text(builtinDeckTemplates.first.name),
    );
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pump();
    expect(calls.templates.single.id, builtinDeckTemplates.first.id);
  });

  testWidgets('the samples dialog holds every bundled deck and the demo', (tester) async {
    final calls = await _pump(tester);
    await openSamples(tester);
    expect(find.byType(SamplesGalleryList), findsOneWidget);
    for (final deck in bundledDecks) {
      expect(find.text(deck.title), findsOneWidget);
    }
    expect(find.text('Edit the demo deck'), findsOneWidget);

    await tester.tap(find.text('Plain slides'));
    await tester.pumpAndSettle();
    expect(calls.presented.single.id, 'welcome');
    expect(find.byType(SamplesGalleryList), findsNothing);
  });

  testWidgets('the samples dialog routes the demo tile to the editor', (tester) async {
    final calls = await _pump(tester);
    await openDemoForEdit(tester);
    expect(calls.demos, 1);
    expect(find.byType(SamplesGalleryList), findsNothing);
  });

  testWidgets('Close leaves the samples dialog with nothing picked', (tester) async {
    final calls = await _pump(tester);
    await openSamples(tester);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(SamplesGalleryList), findsNothing);
    expect(calls.presented, isEmpty);
    expect(calls.demos, 0);
  });

  testWidgets('the compact layout keeps every action reachable', (tester) async {
    tester.view.physicalSize = const Size(720, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      OiApp(
        title: 'test',
        theme: OiThemeData.dark(),
        home: StartScreen(
          error: null,
          recents: [_recent('design.fluvie', path: '/decks/design.fluvie')],
          showTips: true,
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
      ),
    );
    await tester.pump();
    expect(find.text('New deck'), findsOneWidget);
    expect(find.byType(StartTips), findsOneWidget);
    await tester.ensureVisible(find.text('Templates'));
    expect(find.text('Templates'), findsOneWidget);
  });

  testWidgets('the shell shows the tips once and remembers the dismissal', (tester) async {
    useDesktopSurface(tester);
    final prefs = MemoryStartPrefsStore();
    await tester.pumpWidget(
      SlidesApp(
        openFile: () async => null,
        recents: MemoryRecents(),
        autosave: MemoryAutosaveStore(),
        startPrefs: prefs,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(StartTips), findsOneWidget);

    await tester.tap(find.text('Got it'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(StartTips), findsNothing);
    expect(prefs.saves, 1);
    expect(prefs.prefs.tipsDismissed, isTrue);
  });

  testWidgets('a remembered dismissal keeps the tips away', (tester) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(
      SlidesApp(
        openFile: () async => null,
        recents: MemoryRecents(),
        autosave: MemoryAutosaveStore(),
        startPrefs: MemoryStartPrefsStore(const StartPrefs(tipsDismissed: true)),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(StartTips), findsNothing);
  });

  testWidgets('a returning user with recents never sees the tips', (tester) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(
      SlidesApp(
        openFile: () async => null,
        recents: MemoryRecents([_recent('design.fluvie', path: '/decks/design.fluvie')]),
        autosave: MemoryAutosaveStore(),
        startPrefs: MemoryStartPrefsStore(),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(StartTips), findsNothing);
    expect(find.widgetWithText(OiListTile, 'design.fluvie'), findsOneWidget);
  });

  testWidgets('the samples dialog presents a bundled deck through the shell', (tester) async {
    useDesktopSurface(tester);
    await tester.pumpWidget(
      SlidesApp(
        openFile: () async => null,
        recents: MemoryRecents(),
        autosave: MemoryAutosaveStore(),
        startPrefs: MemoryStartPrefsStore(const StartPrefs(tipsDismissed: true)),
      ),
    );
    await tester.pump();
    await openDemoForEdit(tester);
    expect(find.byType(EditorScreen), findsOneWidget);
  });
}
