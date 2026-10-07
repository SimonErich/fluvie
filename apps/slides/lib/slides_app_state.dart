part of 'slides_app.dart';

final class _SlidesAppState extends State<SlidesApp> {
  late final RecentDecksStore _recents = widget.recents ?? RecentDecksStore.platform();
  late final StartPrefsStore _startPrefs = widget.startPrefs ?? StartPrefsStore.platform();
  late final AutosaveStore _autosave = widget.autosave ?? AutosaveStore.platform();
  late final SessionMediaStore _sessionMedia = widget.sessionMedia ?? sessionMediaStore;

  void _storeSpeaker({required String kind, required String payload}) =>
      (widget.storeSpeaker ?? storeSpeakerDeck)(kind: kind, payload: payload);

  /// The recovery prompt needs a context under the shell's navigator; the
  /// start screen (the only screen an edit-open starts from) carries it.
  final GlobalKey _startScreenKey = GlobalKey();
  List<RecentDeck> _recentDecks = const [];

  /// True until the stored preferences arrive, so the tips card never
  /// flashes at a user who already dismissed it.
  bool _tipsDismissed = true;
  Video? _presenting;
  ({EditorDocument document, String title, String key, String? savedDigest})? _editing;

  /// The open deck's recents identity (null for blank and demo decks until
  /// they are saved); a save or rename replaces it in the list.
  RecentDeck? _editingRecent;
  String? _loadError;

  /// A minimal starting deck: one empty canvas slide at HD.
  static Map<String, Object?> blankDeckJson() => {
    'fluvieSpec': 1,
    'size': 'hd',
    'fps': 30,
    'scenes': [
      {
        'duration': '5s',
        'layout': 'canvas',
        'background': {'kind': 'color', 'color': '#101018'},
        'children': <Object?>[],
      },
    ],
  };

  @override
  void initState() {
    super.initState();
    unawaited(_reloadRecents());
    unawaited(_loadStartPrefs());
  }

  /// The recents part lives outside this class; the shim keeps `setState`
  /// inside it.
  void _refresh(VoidCallback change) => setState(change);

  @override
  Widget build(BuildContext context) {
    final presenting = _presenting;
    final editing = _editing;
    return OiApp(
      title: 'fluvie slides',
      theme: OiThemeData.dark(),
      home: presenting != null
          ? _PresentingScreen(
              video: presenting,
              onClose: () => setState(() => _presenting = null),
            )
          : editing != null
          ? EditorScreen(
              document: editing.document,
              title: editing.title,
              // Leaving the editor drops the document's media scope, so the
              // next deck never resolves against the last one's folder.
              onClose: () => setState(() {
                MediaFileBase.current = null;
                _editing = null;
              }),
              saver: widget.saver,
              layoutSettings: widget.layoutSettings,
              autosave: _autosave,
              autosaveKey: editing.key,
              savedDigest: editing.savedDigest,
              sessionMedia: _sessionMedia,
              storeSpeaker: widget.storeSpeaker,
              onDeckSaved: (name, path) => unawaited(_deckTouched(name, path, renameOnly: false)),
              onDeckRenamed: (name, path) => unawaited(_deckTouched(name, path, renameOnly: true)),
            )
          : OiFileDropTarget(
              dropMessage: 'Drop a .fluvie file to present it',
              onInternalDrop: (_, _) {},
              // The barrel hides the drop payload type; inference names it.
              onExternalDrop: (files) {
                if (files.isEmpty) return;
                unawaited(
                  parseDroppedFluvie(files.first.name, files.first.bytes).then((loaded) {
                    if (mounted) _presentLoaded(loaded);
                  }),
                );
              },
              child: StartScreen(
                key: _startScreenKey,
                error: _loadError,
                recents: _recentDecks,
                showTips: !_tipsDismissed && _recentDecks.isEmpty,
                onDismissTips: _dismissTips,
                onPickBundled: _presentBundled,
                onOpenFile: () => unawaited(_presentFile()),
                onOpenRecent: (deck) => unawaited(_openRecent(deck)),
                onNewDeck: () => unawaited(_editDocument('untitled.fluvie', blankDeckJson())),
                onNewFromTemplate: (template) =>
                    unawaited(_editDocument('${template.name}.fluvie', template.deck)),
                onEditDemo: () => unawaited(_editDocument('Demo deck', demoSpecJson)),
                onEditFile: () => unawaited(_editFile()),
              ),
            ),
    );
  }
}
