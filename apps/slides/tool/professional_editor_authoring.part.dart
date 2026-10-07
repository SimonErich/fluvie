part of 'professional_editor_journey.dart';

typedef _AuthoredJourney = ({
  List<String> outputs,
  String digest,
  String titleId,
  EditorDocument reopened,
  void Function(EditorCommand command) command,
});

Future<_AuthoredJourney> _authorJourney(
  WidgetTester tester,
  Directory directory,
  List<MediaPick> picks,
) async {
  final projectFile = File('${directory.path}/journey.fluvie');
  final saver = _SavedProject(projectFile);
  final outputs = <String>[];
  final renderer = DesktopDeckRenderService(
    pickOutput: (name) async {
      final path = '${directory.path}/$name';
      outputs.add(path);
      return path;
    },
  );
  final initial = EditorDocument.fromJson(const {
    'fluvieSpec': 1,
    'fps': 12,
    'size': {'width': 1280, 'height': 720},
    'lanes': [
      {'id': 'picture', 'kind': 'video', 'name': 'Picture'},
      {'id': 'titles', 'kind': 'video', 'name': 'Titles'},
      {'id': 'sound', 'kind': 'audio', 'name': 'Music'},
    ],
    'editor': {
      'deck': {'mode': 'video'},
    },
    'scenes': [
      {'duration': '4s', 'layout': 'canvas', 'children': <Object?>[]},
    ],
  });
  Future<void> mount(EditorDocument document, {MediaImporter? importer}) async {
    await tester.pumpWidget(
      OiApp(
        home: EditorScreen(
          document: document,
          title: 'journey.fluvie',
          key: UniqueKey(),
          onClose: () {},
          importer: importer,
          saver: saver,
          render: renderer,
          autosave: MemoryAutosaveStore(),
        ),
      ),
    );
    await tester.pump();
  }

  await mount(initial, importer: _Imports(picks));
  final originalRender = initial.renderDigest;
  for (var index = 0; index < 3; index++) {
    await tester.tap(find.text('Import media'));
    await tester.pump();
  }
  expect(_canvas(tester).document.mediaEntries, hasLength(3));
  expect(_canvas(tester).document.renderDigest, originalRender);
  final entries = _canvas(tester).document.mediaEntries;
  _timeline(tester).onSourceDropped!((entry: entries[0], start: 12, end: 60), 'lane:picture', 0);
  await tester.pump();
  _timeline(tester).onSourceDropped!((entry: entries[1], start: 12, end: 60), 'lane:picture', 24);
  await tester.pump();
  _timeline(tester).onSourceDropped!((entry: entries[2], start: 500, end: 3500), 'lane:sound', 6);
  await tester.pump();
  var document = _canvas(tester).document;
  final clips = document.elementIdsInScene(0);
  expect(clips, hasLength(2));
  expect(document.elementJson(clips.first)!['trim'], {'from': '0.5s', 'to': '2.5s'});
  void command(EditorCommand command) => _canvas(tester).onCommand!(command);
  final transition = transitionDropped(
    document,
    VideoLaneModel.build(document: document),
    'lane:picture',
    24,
    const TransitionDragData('crossFade', durationFrames: 6),
  );
  expect(transition.command, isNotNull, reason: transition.note);
  command(transition.command!);
  await tester.pump();
  command(
    ApplyColourCommand(
      ids: [clips.first],
      effects: const [
        {'kind': 'grade', 'exposure': 0.15, 'saturation': 0.8},
      ],
    ),
  );
  await tester.pump();
  command(const SetLaneCommand(id: 'sound', patch: {'gain': 0.4}));
  await tester.pump();
  final title = (await tester.runAsync(loadTitleCatalog))!.first;
  command(
    InsertTitleCommand(
      scene: 0,
      title: title.prepare(_canvas(tester).document, 0, 3, lane: 'titles'),
    ),
  );
  await tester.pump();
  document = _canvas(tester).document;
  final titleId = document
      .elementIdsInScene(0)
      .firstWhere((id) => document.elementJson(id)!['type'] == 'SplitText');
  command(
    ReplaceElementCommand(
      id: titleId,
      element: {...document.elementJson(titleId)!, 'text': 'Verified project'},
    ),
  );
  await tester.pump();
  document = _canvas(tester).document;
  final digest = document.renderDigest;
  await tester.tap(find.text('Save'));
  await _until(tester, projectFile.existsSync);
  final reopened = EditorDocument.fromJson(
    jsonDecode(projectFile.readAsStringSync()) as Map<String, Object?>,
  );
  expect(reopened.renderDigest, digest);
  expect(reopened.toJson(), document.toJson());
  await mount(reopened);
  return (outputs: outputs, digest: digest, titleId: titleId, reopened: reopened, command: command);
}

Future<void> _deliverJourney(
  WidgetTester tester,
  Directory directory,
  _AuthoredJourney authored,
) async {
  final outputs = authored.outputs;
  final titleId = authored.titleId;
  final reopened = authored.reopened;
  final command = authored.command;
  final workspace = tester.widget<WorkspaceControl>(find.byType(WorkspaceControl));
  workspace.onChanged(EditorWorkspace.deliver);
  await tester.pump();
  await tester.tap(find.text('Batch 1080p + 720p'));
  await tester.pump();
  // Editing remains live while the real renderer pumps its independent surface.
  command(
    ReplaceElementCommand(
      id: titleId,
      element: {...reopened.elementJson(titleId)!, 'text': 'Next revision'},
    ),
  );
  await tester.pump();
  expect(_canvas(tester).document.elementJson(titleId)!['text'], 'Next revision');
  tester.widget<WorkspaceControl>(find.byType(WorkspaceControl)).onChanged(EditorWorkspace.edit);
  await tester.pump();
  tester.widget<WorkspaceControl>(find.byType(WorkspaceControl)).onChanged(EditorWorkspace.deliver);
  await tester.pump();
  await _until(
    tester,
    () =>
        outputs.length == 2 &&
        outputs.every((path) => File(path).existsSync()) &&
        find.textContaining('Saved ${directory.path}').evaluate().length == 2,
    seconds: 240,
  );
}
