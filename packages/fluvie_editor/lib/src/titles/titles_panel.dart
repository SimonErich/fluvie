import 'package:flutter/widgets.dart';
import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/titles/title_catalog.dart';
import 'package:fluvie_editor/src/titles/title_preview.dart';
import 'package:obers_ui/obers_ui.dart';

/// Inserts complete data-authored titles at the scene-local playhead.
final class TitlesPanel extends StatefulWidget {
  /// [frame] is local to [scene]; [lane] is an optional declared lane id.
  const TitlesPanel({
    required this.document,
    required this.scene,
    required this.frame,
    required this.onCommand,
    this.lane,
    this.onInserted,
    this.catalog,
    super.key,
  });

  /// The open document.
  final EditorDocument document;

  /// The active scene index.
  final int scene;

  /// The scene-local insertion frame.
  final int frame;

  /// The active declared video lane, or null for an implicit element lane.
  final String? lane;

  /// Dispatches the insertion as one undo step.
  final ValueChanged<EditorCommand> onCommand;

  /// Selects the editable text immediately after insertion.
  final ValueChanged<Set<String>>? onInserted;

  /// Optional fixture seam for tests and host-specific title catalogs.
  final Future<List<TitleTemplate>>? catalog;
  @override
  State<TitlesPanel> createState() => _TitlesPanelState();
}

final class _TitlesPanelState extends State<TitlesPanel> {
  late Future<List<TitleTemplate>> _catalog = widget.catalog ?? loadTitleCatalog();
  String _query = '';
  final TextEditingController _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const OiLabel.body('Titles'),
        OiTextInput(
          controller: _search,
          placeholder: 'Search titles',
          onChanged: (text) => setState(() => _query = text.toLowerCase()),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: FutureBuilder<List<TitleTemplate>>(
            future: _catalog,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Column(
                  children: [
                    OiLabel.small('Titles could not load: ${snapshot.error}'),
                    OiButton.ghost(
                      fullWidth: true,
                      label: 'Retry',
                      onTap: () => setState(() => _catalog = loadTitleCatalog()),
                    ),
                  ],
                );
              }
              final titles = snapshot.data;
              if (titles == null) return const OiLabel.small('Loading titles…');
              return ListView(
                children: [
                  for (final title in titles)
                    if ('${title.name} ${title.family}'.toLowerCase().contains(_query))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            OiLabel.small(title.family),
                            TitlePreview(key: ValueKey(title.name), title: title),
                            OiButton.ghost(
                              fullWidth: true,
                              label: title.name,
                              onTap: () {
                                final prepared = title.prepare(
                                  widget.document,
                                  widget.scene,
                                  widget.frame,
                                  lane: widget.lane,
                                );
                                widget.onCommand(
                                  InsertTitleCommand(scene: widget.scene, title: prepared),
                                );
                                final text = (prepared['children']! as List)
                                    .cast<Map<String, Object?>>()
                                    .where(
                                      (element) =>
                                          const {'Text', 'SplitText'}.contains(element['type']),
                                    )
                                    .firstOrNull;
                                if (text != null) widget.onInserted?.call({text['id']! as String});
                              },
                            ),
                          ],
                        ),
                      ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}
