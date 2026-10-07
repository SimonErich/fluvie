import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData;

Future<ProviderContainer> _pump(WidgetTester tester, {VoidCallback? onAssets}) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: OiApp(
        title: 'test',
        theme: OiThemeData.dark(),
        home: Center(child: EditorToolbar(onAssets: onAssets)),
      ),
    ),
  );
  return container;
}

void main() {
  testWidgets('every tool has a labelled button that activates it', (tester) async {
    final container = await _pump(tester);
    ToolState state() => container.read(toolProvider);

    await tester.tap(find.bySemanticsLabel('Text tool (T)'));
    expect(state().tool, EditorTool.text);
    await tester.tap(find.bySemanticsLabel('Ellipse tool (O)'));
    expect(state(), const ToolState(tool: EditorTool.shape, shape: ShapeVariant.ellipse));
    await tester.tap(find.bySemanticsLabel('Arrow tool (A)'));
    expect(state(), const ToolState(tool: EditorTool.shape, shape: ShapeVariant.arrow));
    await tester.tap(find.bySemanticsLabel('Hand tool (H)'));
    expect(state().tool, EditorTool.hand);
    await tester.tap(find.bySemanticsLabel('Select tool (V)'));
    expect(state().tool, EditorTool.select);
    await tester.tap(find.bySemanticsLabel('Rectangle tool (R)'));
    expect(state(), const ToolState(tool: EditorTool.shape));
    await tester.tap(find.bySemanticsLabel('Line tool (L)'));
    expect(state(), const ToolState(tool: EditorTool.shape, shape: ShapeVariant.line));
    await tester.tap(find.bySemanticsLabel('Media tool (M)'));
    expect(state().tool, EditorTool.media);
  });

  testWidgets('the rulers button toggles the preference', (tester) async {
    final container = await _pump(tester);
    expect(container.read(snapPreferencesProvider).rulers, isFalse);

    await tester.tap(find.bySemanticsLabel('Rulers and guides'));
    expect(container.read(snapPreferencesProvider).rulers, isTrue);
    await tester.tap(find.bySemanticsLabel('Rulers and guides'));
    expect(container.read(snapPreferencesProvider).rulers, isFalse);
  });

  testWidgets('the assets button appears only when offered and fires', (tester) async {
    await _pump(tester);
    expect(find.bySemanticsLabel('Deck assets'), findsNothing);

    var opened = 0;
    await _pump(tester, onAssets: () => opened++);
    await tester.tap(find.bySemanticsLabel('Deck assets'));
    expect(opened, 1);
  });

  testWidgets('the asset panel lists media and hands back a pick', (tester) async {
    final document = EditorDocument.fromJson(const {
      'fluvieSpec': 1,
      'size': 'hd',
      'fps': 30,
      'scenes': [
        {
          'duration': '60f',
          'children': [
            {
              'type': 'Image',
              'source': {'kind': 'file', 'value': '/media/photo.png'},
            },
          ],
        },
      ],
    });
    MediaPick? picked;
    await tester.pumpWidget(
      OiApp(
        title: 'test',
        theme: OiThemeData.dark(),
        home: Center(
          child: SizedBox(
            width: 300,
            child: AssetReusePanel(document: document, onPick: (pick) => picked = pick),
          ),
        ),
      ),
    );
    expect(find.text('photo.png'), findsOneWidget);
    await tester.tap(find.text('photo.png'));
    expect(picked, isNotNull);
    expect(picked!.source['value'], '/media/photo.png');
    expect(picked!.isVideo, isFalse);
  });

  testWidgets('the asset panel lists store entries once, audio unpickable', (tester) async {
    final document =
        EditorDocument.fromJson(const {
              'fluvieSpec': 1,
              'size': 'hd',
              'fps': 30,
              'scenes': [
                {
                  'duration': '60f',
                  'children': [
                    {
                      'type': 'Image',
                      'source': {'kind': 'file', 'value': '/media/photo.png'},
                    },
                  ],
                },
              ],
            })
            .addMediaEntry(
              const MediaStoreEntry(
                id: 'media-1',
                name: 'photo.png',
                kind: MediaStoreKind.image,
                source: {'kind': 'file', 'value': '/media/photo.png'},
              ),
            )
            .addMediaEntry(
              const MediaStoreEntry(
                id: 'media-2',
                name: 'bed.mp3',
                kind: MediaStoreKind.audio,
                source: {'kind': 'file', 'value': '/media/bed.mp3'},
              ),
            );
    MediaPick? picked;
    final commands = <EditorCommand>[];
    await tester.pumpWidget(
      OiApp(
        title: 'test',
        theme: OiThemeData.dark(),
        home: Center(
          child: SizedBox(
            width: 300,
            child: AssetReusePanel(
              document: document,
              onPick: (pick) => picked = pick,
              onCommand: commands.add,
            ),
          ),
        ),
      ),
    );
    // The used image is already a store entry: one tile, not two.
    expect(find.text('photo.png'), findsOneWidget);
    expect(find.text('bed.mp3'), findsOneWidget);

    await tester.tap(find.text('bed.mp3'));
    expect(picked, isNull, reason: 'audio waits for the timeline tracks');

    await tester.tap(find.text('photo.png'));
    expect(picked!.source['value'], '/media/photo.png');

    await tester.tap(find.bySemanticsLabel('Remove bed.mp3').first);
    expect(commands.single, isA<RemoveMediaEntryCommand>());
    expect((commands.single as RemoveMediaEntryCommand).id, 'media-2');
  });

  testWidgets('an empty deck invites the media tool', (tester) async {
    final document = EditorDocument.fromJson(const {
      'fluvieSpec': 1,
      'size': 'hd',
      'fps': 30,
      'scenes': [
        {'duration': '60f', 'children': <Object?>[]},
      ],
    });
    await tester.pumpWidget(
      OiApp(
        title: 'test',
        theme: OiThemeData.dark(),
        home: Center(
          child: SizedBox(
            width: 300,
            child: AssetReusePanel(document: document, onPick: (_) {}),
          ),
        ),
      ),
    );
    expect(find.textContaining('No media in this deck yet'), findsOneWidget);
  });

  testWidgets('the asset panel offers an import control above the media', (tester) async {
    final document = EditorDocument.fromJson(const {
      'fluvieSpec': 1,
      'size': 'hd',
      'fps': 30,
      'scenes': [
        {
          'duration': '60f',
          'children': [
            {
              'type': 'Image',
              'source': {'kind': 'file', 'value': '/media/photo.png'},
            },
          ],
        },
      ],
    });
    var imported = 0;
    await tester.pumpWidget(
      OiApp(
        title: 'test',
        theme: OiThemeData.dark(),
        home: Center(
          child: SizedBox(
            width: 300,
            child: AssetReusePanel(
              document: document,
              onPick: (_) {},
              onImport: () => imported++,
            ),
          ),
        ),
      ),
    );
    expect(find.text('photo.png'), findsOneWidget);
    expect(find.text('Import media'), findsOneWidget);
    await tester.tap(find.text('Import media'));
    expect(imported, 1);
  });

  testWidgets('an empty asset panel still offers import when wired', (tester) async {
    final document = EditorDocument.fromJson(const {
      'fluvieSpec': 1,
      'size': 'hd',
      'fps': 30,
      'scenes': [
        {'duration': '60f', 'children': <Object?>[]},
      ],
    });
    var imported = 0;
    await tester.pumpWidget(
      OiApp(
        title: 'test',
        theme: OiThemeData.dark(),
        home: Center(
          child: SizedBox(
            width: 300,
            child: AssetReusePanel(
              document: document,
              onPick: (_) {},
              onImport: () => imported++,
            ),
          ),
        ),
      ),
    );
    // The empty state still surfaces the import affordance, not just the
    // media-tool hint.
    expect(find.textContaining('No media in this deck yet'), findsNothing);
    expect(find.text('Import media'), findsOneWidget);
    await tester.tap(find.text('Import media'));
    expect(imported, 1);
  });

  testWidgets('the asset panel hides the import control without a handler', (tester) async {
    final document = EditorDocument.fromJson(const {
      'fluvieSpec': 1,
      'size': 'hd',
      'fps': 30,
      'scenes': [
        {
          'duration': '60f',
          'children': [
            {
              'type': 'Image',
              'source': {'kind': 'file', 'value': '/media/photo.png'},
            },
          ],
        },
      ],
    });
    await tester.pumpWidget(
      OiApp(
        title: 'test',
        theme: OiThemeData.dark(),
        home: Center(
          child: SizedBox(
            width: 300,
            child: AssetReusePanel(document: document, onPick: (_) {}),
          ),
        ),
      ),
    );
    expect(find.text('photo.png'), findsOneWidget);
    expect(find.text('Import media'), findsNothing);
  });
}
